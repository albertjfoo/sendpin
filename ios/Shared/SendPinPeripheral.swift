//
//  SendPinPeripheral.swift
//  sendpin
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
enum SendPinBLE {
    /// Custom waypoint service. Random 128-bit UUID: deliberately *not* built
    /// on the Bluetooth SIG base (`…-0000-1000-8000-00805F9B34FB`), so neither
    /// CoreBluetooth nor Android's ParcelUuid will silently shorten it to 16
    /// bits and confuse a scan filter.
    static let waypointService = CBUUID(string: "4B027EEA-0001-45A6-AB37-310A7471C7DC")

    /// Readable characteristic holding the UTF-8 JSON waypoint.
    static let waypointCharacteristic = CBUUID(string: "4B027EEA-0002-45A6-AB37-310A7471C7DC")


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
final class SendPinPeripheral: NSObject {

    // MARK: Observable state

    private(set) var managerState: CBManagerState = .unknown
    private(set) var isAdvertising = false
    private(set) var subscriberCount = 0
    private(set) var readCount = 0
    /// True once we have been advertising a while with nothing having read us.
    /// The phone cannot detect whether the Karoo extension exists — it only
    /// ever learns anything when something connects — so silence is the only
    /// signal available, and it has to be surfaced rather than left looking
    /// like progress.
    private(set) var noResponseYet = false
    private(set) var log: [PeripheralLogEntry] = []

    /// Whatever is here is what a connecting central reads. Set it before you
    /// start advertising.
    var waypoint: Waypoint = .none


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
    private var waypointCharacteristic: CBMutableCharacteristic?
    private var deliveryTimer: Timer?
    private var responseTimer: Timer?
    private var readCountAtAdvertiseStart = 0

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
        deliveryTimer?.invalidate()
        deliveryTimer = nil
        responseTimer?.invalidate()
        responseTimer = nil
        noResponseYet = false
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
        servedPayload = destination.wireData(deviceID: DeviceID.current)
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
            type: SendPinBLE.waypointCharacteristic,
            properties: [.read, .notify],
            value: nil,                 // must be nil — see below
            permissions: [.readable])
        waypointCharacteristic = waypointChar

        let waypointService = CBMutableService(type: SendPinBLE.waypointService, primary: true)
        waypointService.characteristics = [waypointChar]
        pendingServiceAdds += 1
        manager.add(waypointService)
    }

    private func beginAdvertising() {
        guard let manager, !isAdvertising else { return }

        // Pin the bytes for the whole advertising session, so a long (blob)
        // read served across several ATT round trips cannot see the payload
        // change underneath it halfway through.
        servedPayload = waypoint.wireData(deviceID: DeviceID.current)

        // R5: the advertisement is 31 bytes and a 128-bit UUID eats most of it.
        // Overflow gets pushed to the Apple-only overflow area, where an Android
        // central like the Karoo cannot see it — so the budget is real and worth
        // counting rather than guessing at:
        //
        //   flags                    3
        //   128-bit service UUID  2 + 16
        //   local name "KSend"    2 +  5
        //                         --------
        //                              28  of 31
        //
        // Three bytes spare. Do not lengthen the name without redoing this.
        //
        // iOS supports only these two keys — no manufacturer data, no service
        // data — which is why the waypoint travels over GATT rather than riding
        // in the advertisement itself.
        manager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [SendPinBLE.waypointService],
            CBAdvertisementDataLocalNameKey: "KSend",
        ])
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
        append(.info, "expected sendpin://send?lat=…&lng=…&name=…")
    }
}

// MARK: - CBPeripheralManagerDelegate

extension SendPinPeripheral: CBPeripheralManagerDelegate {

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
            // Deliberately no early return. A failed add still has to fall
            // through to the readiness check below, or the last add failing
            // leaves servicesReady false forever and Start silently does
            // nothing — which is exactly what happened on 2026-08-06.
            append(.failure, "failed to add \(service.uuid): \(error.localizedDescription)")
        } else {
            append(.info, "added service \(service.uuid)")
        }

        // Advertise once every add has resolved, successfully or not.
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
        armNoResponseWatchdog()
        append(.success, "advertising \"KSend\" + waypoint service UUID")
        append(.info, "serving \(waypoint.summary) — \(servedPayload.count) bytes")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didSubscribeTo characteristic: CBCharacteristic) {
        subscriberCount += 1
        append(.success, "SUBSCRIBED to \(characteristic.uuid) — something connected")
        // maximumUpdateValueLength is the negotiated ATT MTU minus overhead.
        // ~20 means the default MTU, which is what forces blob reads for the
        // waypoint payload; anything larger means the central negotiated up.
        append(.info, "central max write \(central.maximumUpdateValueLength) bytes")

    }

    /// Fires when the transmit queue drains after updateValue returned false.
    /// Only relevant to the notify path in send(), where a pushed destination
    /// can be deferred; a plain read is unaffected.
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        append(.info, "transmit queue ready")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didUnsubscribeFrom characteristic: CBCharacteristic) {
        subscriberCount = max(0, subscriberCount - 1)
        append(.info, "unsubscribed from \(characteristic.uuid)")
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           didReceiveRead request: CBATTRequest) {
        // Every read is evidence that a central is connected and walking the
        // GATT database — the only such evidence CoreBluetooth gives us in the
        // peripheral role, since there is no didConnect callback.
        guard request.characteristic.uuid == SendPinBLE.waypointCharacteristic else {
            // Characteristics built with a cached `value` are answered by
            // CoreBluetooth itself and never reach here, so anything landing
            // in this branch is genuinely unexpected and worth seeing.
            append(.warning, "read of unhandled \(request.characteristic.uuid)")
            peripheral.respond(to: request, withResult: .attributeNotFound)
            return
        }

        // The payload is bigger than the 20 usable bytes of a default-MTU ATT
        // response, so the central will fetch it as a series of blob reads with
        // an increasing offset. Ignoring request.offset here would hand back
        // the first chunk over and over and the central would assemble garbage.
        let payload = servedPayload.isEmpty ? waypoint.wireData(deviceID: DeviceID.current) : servedPayload
        guard request.offset <= payload.count else {
            peripheral.respond(to: request, withResult: .invalidOffset)
            return
        }

        request.value = payload.subdata(in: request.offset ..< payload.count)
        peripheral.respond(to: request, withResult: .success)

        noResponseYet = false
        responseTimer?.invalidate()

        if request.offset == 0 {
            readCount += 1
            append(.success, "waypoint read by central (\(payload.count) bytes)")
        }

        scheduleDeliveryFinish()
    }

    /// Stop advertising once the Karoo has actually taken the payload.
    ///
    /// Debounced rather than fired on the first read, because a central with a
    /// small MTU fetches the payload as several blob reads; stopping on the
    /// first one would cut the transfer off midway. Any further read resets the
    /// timer, so this only fires when the central has gone quiet.
    ///
    /// Worth doing because the phone otherwise keeps advertising indefinitely —
    /// it has no idea the destination arrived. On 2026-08-06 that had the Karoo
    /// reconnecting over and over to re-read a waypoint it already had.
    /// A send normally completes in about two seconds. Well past that with no
    /// read at all means something is wrong at the other end — most often the
    /// extension is not installed, is switched off, or never got location
    /// permission. Say so instead of showing "Sending…" indefinitely.
    private func armNoResponseWatchdog() {
        noResponseYet = false
        readCountAtAdvertiseStart = readCount
        responseTimer?.invalidate()
        responseTimer = Timer.scheduledTimer(withTimeInterval: 25, repeats: false) {
            [weak self] _ in
            guard let self, self.isAdvertising,
                  self.readCount == self.readCountAtAdvertiseStart else { return }
            self.noResponseYet = true
            self.append(.warning, "nothing has read this yet — is the Karoo extension listening?")
        }
    }

    private func scheduleDeliveryFinish() {
        deliveryTimer?.invalidate()
        deliveryTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) {
            [weak self] _ in
            guard let self, self.isAdvertising else { return }
            self.append(.success, "destination delivered — stopped advertising")
            self.stop()
        }
    }
}
