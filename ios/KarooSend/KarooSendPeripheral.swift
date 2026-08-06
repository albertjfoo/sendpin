//
//  KarooSendPeripheral.swift
//  karoo2-send
//
//  The iPhone half of the link: a BLE peripheral that holds a {lat, lng, name}
//  waypoint in a GATT characteristic and waits for the Karoo to come read it.
//
//  ⚠️ CoreBluetooth does NOT work in the iOS Simulator. Run on a real iPhone.
//     The Simulator reports .unsupported and nothing else ever happens.
//  ⚠️ Info.plist MUST contain NSBluetoothAlwaysUsageDescription, or iOS 13+
//     refuses Bluetooth and the peripheral silently fails as .unauthorized.
//
//  All CBPeripheralManagerDelegate callbacks arrive on the main queue, because
//  we construct the manager with queue: nil. That is what makes it safe for
//  SwiftUI to observe this object directly.
//

import CoreBluetooth
import Foundation
import Observation

// MARK: - Protocol constants

/// The wire contract with the Karoo extension. Changing either UUID means
/// changing the Kotlin side in lockstep — see PROTOCOL.md.
enum KarooSendBLE {
    /// Custom waypoint service. Random 128-bit UUID: deliberately *not* built
    /// on the Bluetooth SIG base (`…-0000-1000-8000-00805F9B34FB`), so neither
    /// CoreBluetooth nor Android's ParcelUuid will silently shorten it to 16
    /// bits and confuse a scan filter.
    static let waypointService = CBUUID(string: "4B027EEA-0001-45A6-AB37-310A7471C7DC")

    /// Readable characteristic holding the UTF-8 JSON waypoint.
    static let waypointCharacteristic = CBUUID(string: "4B027EEA-0002-45A6-AB37-310A7471C7DC")

    /// Bluetooth SIG Heart Rate service + Measurement characteristic. Used only
    /// by the milestone-1 test harness, never by the shipping product.
    static let heartRateService = CBUUID(string: "180D")
    static let heartRateMeasurement = CBUUID(string: "2A37")
}

// MARK: - Advertising mode

enum AdvertisingMode: String, CaseIterable, Identifiable {
    /// Milestone 1. Masquerade as a heart rate monitor so the Karoo's own
    /// Settings → Sensors → Add Sensor screen becomes the test harness. Proves
    /// BLE discovery end-to-end with zero Kotlin written.
    case heartRateTestHarness

    /// The product. Advertise only the custom waypoint service; the Karoo
    /// extension scans for that UUID, connects, and reads the payload.
    case waypoint

    var id: String { rawValue }

    var label: String {
        switch self {
        case .heartRateTestHarness: "HR test harness"
        case .waypoint: "Waypoint"
        }
    }

    var explanation: String {
        switch self {
        case .heartRateTestHarness:
            "Advertises service 180D as \"KarooSend\". Look for it in Karoo → Settings → Sensors → Add Sensor → Heart Rate."
        case .waypoint:
            "Advertises only the custom waypoint service, no local name. Needs the Karoo extension to be listening."
        }
    }
}

// MARK: - Log

struct PeripheralLogEntry: Identifiable {
    enum Level { case info, success, warning, failure }

    let id = UUID()
    let date = Date()
    let level: Level
    let text: String
}

// MARK: - Peripheral

@Observable
final class KarooSendPeripheral: NSObject {

    // MARK: Observable state

    private(set) var managerState: CBManagerState = .unknown
    private(set) var isAdvertising = false
    private(set) var subscriberCount = 0
    private(set) var readCount = 0
    private(set) var log: [PeripheralLogEntry] = []

    /// Whatever is here is what a connecting central reads. Set it before you
    /// start advertising.
    var waypoint: Waypoint = .none

    var mode: AdvertisingMode = .heartRateTestHarness {
        didSet {
            guard oldValue != mode else { return }
            append(.info, "mode → \(mode.label)")
            // The GATT database differs per mode, so a live session has to be
            // torn down and rebuilt rather than just re-advertised.
            if isAdvertising || servicesReady {
                restart()
            }
        }
    }

    var statusText: String {
        switch managerState {
        case .poweredOn: isAdvertising ? "Advertising" : "Ready"
        case .poweredOff: "Bluetooth is off"
        case .unauthorized: "Bluetooth permission denied"
        case .unsupported: "Unsupported (Simulator?)"
        case .resetting: "Bluetooth resetting"
        default: "Starting…"
        }
    }

    var canAdvertise: Bool { managerState == .poweredOn }

    // MARK: Private state

    private var manager: CBPeripheralManager?
    private var hrCharacteristic: CBMutableCharacteristic?
    private var waypointCharacteristic: CBMutableCharacteristic?
    private var notifyTimer: Timer?
    private var bpm: UInt8 = 72

    /// Services are added asynchronously; we must not advertise until every
    /// add has come back through didAdd, or the GATT database a central sees
    /// can be incomplete.
    private var pendingServiceAdds = 0
    private var servicesReady = false
    private var wantsToAdvertise = false

    /// The waypoint bytes captured at the moment advertising started. Pinned so
    /// that a long (blob) read served across several ATT round trips cannot see
    /// the payload change underneath it halfway through.
    private var servedPayload = Data()

    // MARK: - Lifecycle

    /// Bring up CoreBluetooth. Safe to call more than once.
    func activate() {
        guard manager == nil else { return }
        append(.info, "starting CoreBluetooth")
        // queue: nil → all delegate callbacks land on the main queue.
        manager = CBPeripheralManager(delegate: self, queue: nil)
    }

    /// Begin advertising in the current mode.
    func start() {
        activate()
        wantsToAdvertise = true
        guard let manager, manager.state == .poweredOn else {
            append(.info, "waiting for Bluetooth to power on")
            return
        }
        if servicesReady {
            beginAdvertising()
        } else {
            buildServices()
        }
    }

    /// Stop advertising and tear the GATT database down. R3: iOS only
    /// advertises reliably in the foreground anyway, so there is no value in
    /// holding this open — and it costs battery on both ends.
    func stop() {
        wantsToAdvertise = false
        notifyTimer?.invalidate()
        notifyTimer = nil
        subscriberCount = 0

        guard let manager else { return }
        if isAdvertising {
            manager.stopAdvertising()
            isAdvertising = false
            append(.info, "stopped advertising")
        }
        manager.removeAllServices()
        servicesReady = false
        pendingServiceAdds = 0
        hrCharacteristic = nil
        waypointCharacteristic = nil
    }

    /// Replace the destination being served, and start advertising if we
    /// weren't already. This is the one call the URL handler needs.
    func send(_ destination: Waypoint) {
        waypoint = destination
        append(.info, "waypoint ← \(destination.summary)")

        guard isAdvertising else {
            start()
            return
        }

        // Already live: swap the served bytes and push to anyone subscribed so
        // they don't have to reconnect for the new destination.
        servedPayload = destination.encoded
        guard let characteristic = waypointCharacteristic, subscriberCount > 0 else { return }
        let delivered = manager?.updateValue(servedPayload,
                                             for: characteristic,
                                             onSubscribedCentrals: nil) ?? false
        // A false return only means the transmit queue is full — the central
        // can still read the characteristic, so this stays best-effort.
        append(.info, delivered ? "pushed to subscribers" : "push deferred, transmit queue full")
    }

    private func restart() {
        let shouldResume = wantsToAdvertise
        stop()
        if shouldResume { start() }
    }

    // MARK: - GATT setup

    private func buildServices() {
        guard let manager, manager.state == .poweredOn else { return }

        manager.removeAllServices()
        servicesReady = false
        pendingServiceAdds = 0

        // --- Waypoint service: the actual product ---
        // .read for the payload, .notify so the extension can subscribe and be
        // pushed a new destination without reconnecting.
        let waypointChar = CBMutableCharacteristic(
            type: KarooSendBLE.waypointCharacteristic,
            properties: [.read, .notify],
            value: nil,                 // must be nil — see below
            permissions: [.readable])
        waypointCharacteristic = waypointChar

        let waypointService = CBMutableService(type: KarooSendBLE.waypointService, primary: true)
        waypointService.characteristics = [waypointChar]
        pendingServiceAdds += 1
        manager.add(waypointService)

        // --- Heart rate service: milestone-1 discovery decoy only ---
        if mode == .heartRateTestHarness {
            // A .notify characteristic MUST be created with value: nil.
            // CoreBluetooth throws if you cache a value on one, because a
            // cached value implies read-only.
            let hrChar = CBMutableCharacteristic(
                type: KarooSendBLE.heartRateMeasurement,
                properties: [.notify],
                value: nil,
                permissions: [.readable])
            hrCharacteristic = hrChar

            let hrService = CBMutableService(type: KarooSendBLE.heartRateService, primary: true)
            hrService.characteristics = [hrChar]
            pendingServiceAdds += 1
            manager.add(hrService)
        } else {
            hrCharacteristic = nil
        }
    }

    private func beginAdvertising() {
        guard let manager, !isAdvertising else { return }

        // Pin the bytes for the whole advertising session.
        servedPayload = waypoint.encoded

        // THE critical line — the thing LightBlue never did, and the reason the
        // Karoo never saw the phone during the NUC session. Adding a service
        // via manager.add() does NOT put its UUID in the advertisement; it has
        // to be listed here explicitly, and Karoo filters scans by service UUID.
        //
        // iOS supports only these two advertisement keys. No manufacturer data,
        // no service data — which is why the waypoint payload can never ride in
        // the advertisement and must travel over GATT after connecting (R4).
        var data: [String: Any] = [:]

        switch mode {
        case .heartRateTestHarness:
            // 180D is 16-bit, so there is plenty of room left for a name.
            data[CBAdvertisementDataServiceUUIDsKey] = [KarooSendBLE.heartRateService]
            data[CBAdvertisementDataLocalNameKey] = "KarooSend"

        case .waypoint:
            // R5: the advertisement is ~31 bytes and a 128-bit UUID eats 16 of
            // them. Adding a local name on top pushes data into the Apple-only
            // "overflow area", where an Android central like the Karoo cannot
            // see it. So: UUID only, no name.
            data[CBAdvertisementDataServiceUUIDsKey] = [KarooSendBLE.waypointService]
        }

        manager.startAdvertising(data)
    }

    // MARK: - Heart rate simulation

    /// Karoo drops a "sensor" that connects and then says nothing, so emit
    /// plausible readings to hold the connection open long enough to confirm
    /// the pairing worked.
    private func startHeartRateNotifications() {
        notifyTimer?.invalidate()
        notifyTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let characteristic = self.hrCharacteristic else { return }
            self.bpm = 60 + ((self.bpm - 60 + 1) % 40)
            // HR Measurement format: flags byte (0x00 = uint8 BPM) + value.
            self.manager?.updateValue(Data([0x00, self.bpm]),
                                      for: characteristic,
                                      onSubscribedCentrals: nil)
        }
    }

    // MARK: - Logging

    private func append(_ level: PeripheralLogEntry.Level, _ text: String) {
        log.append(PeripheralLogEntry(level: level, text: text))
        // The log is on-screen and unbounded input; keep the tail only.
        if log.count > 200 { log.removeFirst(log.count - 200) }
        print("[ble] \(text)")
    }

    func clearLog() { log.removeAll() }

    /// Surfaced on screen rather than silently dropped — a malformed Shortcut
    /// URL is the most likely failure once this is wired to Maps, and there is
    /// no console to check while you are standing over the bike.
    func reportBadURL(_ url: URL) {
        append(.failure, "could not parse \(url.absoluteString)")
        append(.info, "expected karoosend://send?lat=…&lng=…&name=…")
    }
}

// MARK: - CBPeripheralManagerDelegate

extension KarooSendPeripheral: CBPeripheralManagerDelegate {

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        managerState = peripheral.state

        // Nothing works until .poweredOn. Do not advertise before this.
        switch peripheral.state {
        case .poweredOn:
            append(.info, "Bluetooth powered on")
            if wantsToAdvertise { buildServices() }
        case .unauthorized:
            append(.failure, "UNAUTHORIZED — is NSBluetoothAlwaysUsageDescription in Info.plist?")
        case .poweredOff:
            append(.warning, "Bluetooth is off")
            isAdvertising = false
            servicesReady = false
        case .unsupported:
            append(.failure, "unsupported — CoreBluetooth needs a real iPhone, not the Simulator")
        case .resetting:
            append(.warning, "Bluetooth resetting")
            isAdvertising = false
            servicesReady = false
        default:
            append(.info, "state \(peripheral.state.rawValue)")
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           didAdd service: CBService,
                           error: Error?) {
        pendingServiceAdds = max(0, pendingServiceAdds - 1)

        if let error {
            append(.failure, "failed to add \(service.uuid): \(error.localizedDescription)")
            return
        }
        append(.info, "added service \(service.uuid)")

        // Only advertise once every service is in place.
        if pendingServiceAdds == 0 {
            servicesReady = true
            if wantsToAdvertise { beginAdvertising() }
        }
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager,
                                              error: Error?) {
        if let error {
            isAdvertising = false
            append(.failure, "advertising failed: \(error.localizedDescription)")
            return
        }
        isAdvertising = true

        switch mode {
        case .heartRateTestHarness:
            append(.success, "advertising as \"KarooSend\" with 180D in the packet")
            append(.info, "now open Karoo → Settings → Sensors → Add Sensor → Heart Rate")
        case .waypoint:
            append(.success, "advertising waypoint service, no local name")
            append(.info, "serving \(waypoint.summary) — \(servedPayload.count) bytes")
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didSubscribeTo characteristic: CBCharacteristic) {
        subscriberCount += 1
        append(.success, "SUBSCRIBED to \(characteristic.uuid) — something connected")

        if characteristic.uuid == KarooSendBLE.heartRateMeasurement {
            startHeartRateNotifications()
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didUnsubscribeFrom characteristic: CBCharacteristic) {
        subscriberCount = max(0, subscriberCount - 1)
        append(.info, "unsubscribed from \(characteristic.uuid)")

        if characteristic.uuid == KarooSendBLE.heartRateMeasurement, subscriberCount == 0 {
            notifyTimer?.invalidate()
            notifyTimer = nil
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           didReceiveRead request: CBATTRequest) {
        guard request.characteristic.uuid == KarooSendBLE.waypointCharacteristic else {
            peripheral.respond(to: request, withResult: .attributeNotFound)
            return
        }

        // The payload is bigger than the 20 usable bytes of a default-MTU ATT
        // response, so the central will fetch it as a series of blob reads with
        // an increasing offset. Ignoring request.offset here would hand back
        // the first chunk over and over and the central would assemble garbage.
        let payload = servedPayload.isEmpty ? waypoint.encoded : servedPayload
        guard request.offset <= payload.count else {
            peripheral.respond(to: request, withResult: .invalidOffset)
            return
        }

        request.value = payload.subdata(in: request.offset ..< payload.count)
        peripheral.respond(to: request, withResult: .success)

        if request.offset == 0 {
            readCount += 1
            append(.success, "waypoint read by central (\(payload.count) bytes)")
        }
    }
}
