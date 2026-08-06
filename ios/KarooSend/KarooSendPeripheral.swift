//
//  KarooSendPeripheral.swift
//  karoo2-send — milestone 1 test peripheral
//
//  GOAL: make the iPhone appear in the Karoo 2's native
//  Settings → Sensors → Add Sensor list as a heart rate sensor.
//  If that works, BLE discovery is proven end-to-end with NO Kotlin
//  extension involved yet.
//
//  WHY THIS EXISTS: LightBlue's virtual peripheral advertises only a local
//  name and never puts the 180D service UUID in the ADVERTISEMENT PACKET.
//  Karoo filters scan results by service UUID, so it never matched. Verified
//  2026-08-05 by scanning the iPhone from a Linux box: "Name: Heart Rate"
//  with no UUIDs field, while other devices in the same scan did report one.
//
//  ⚠️ CoreBluetooth does NOT work in the iOS Simulator. Run on a real iPhone.
//  ⚠️ Info.plist MUST contain NSBluetoothAlwaysUsageDescription or this crashes.
//

import CoreBluetooth
import Foundation

final class KarooSendPeripheral: NSObject {

    // MARK: - UUIDs

    /// Standard Bluetooth SIG Heart Rate service. Advertised so Karoo's native
    /// sensor pairing can filter for and find us.
    private let hrServiceUUID = CBUUID(string: "180D")
    /// Standard HR Measurement characteristic. Must support .notify.
    private let hrMeasurementUUID = CBUUID(string: "2A37")

    /// Our own waypoint service. NOTE: deliberately NOT advertised — see
    /// startAdvertising() below for why.
    private let waypointServiceUUID =
        CBUUID(string: "A1B2C0DE-0001-4000-8000-00805F9B34FB")
    private let waypointCharUUID =
        CBUUID(string: "A1B2C0DE-0002-4000-8000-00805F9B34FB")

    // MARK: - State

    private var manager: CBPeripheralManager!
    private var hrCharacteristic: CBMutableCharacteristic!
    private var waypointCharacteristic: CBMutableCharacteristic!
    private var notifyTimer: Timer?
    private var bpm: UInt8 = 72

    /// Set this before a send; whatever is here is what a connected central reads.
    /// Real payload will be {lat, lng, name} — JSON is fine to start.
    var pendingWaypoint: Data = Data(#"{"lat":0,"lng":0,"name":"none"}"#.utf8)

    // MARK: - Lifecycle

    func start() {
        // Delegate callbacks arrive on this queue; nil == main queue.
        manager = CBPeripheralManager(delegate: self, queue: nil)
    }

    func stop() {
        notifyTimer?.invalidate()
        notifyTimer = nil
        manager.stopAdvertising()
        manager.removeAllServices()
    }

    // MARK: - GATT setup

    private func buildServices() {
        // --- Heart Rate service (the discovery decoy) ---
        // Notify characteristics MUST be created with value: nil, otherwise
        // CoreBluetooth throws — a cached value makes it read-only.
        hrCharacteristic = CBMutableCharacteristic(
            type: hrMeasurementUUID,
            properties: [.notify],
            value: nil,
            permissions: [.readable])

        let hrService = CBMutableService(type: hrServiceUUID, primary: true)
        hrService.characteristics = [hrCharacteristic]

        // --- Waypoint service (the actual payload) ---
        waypointCharacteristic = CBMutableCharacteristic(
            type: waypointCharUUID,
            properties: [.read, .notify],
            value: nil,
            permissions: [.readable])

        let waypointService = CBMutableService(type: waypointServiceUUID, primary: true)
        waypointService.characteristics = [waypointCharacteristic]

        manager.add(hrService)
        manager.add(waypointService)
    }

    private func startAdvertising() {
        // THE critical line — the thing LightBlue never did.
        // Adding a service via manager.add() does NOT advertise its UUID;
        // it must be listed here explicitly.
        //
        // We advertise ONLY 180D, not the waypoint service, on purpose:
        //   1. The BLE advertisement is ~31 bytes. A 128-bit custom UUID eats 16
        //      of them; combined with the name, iOS would shove UUIDs into the
        //      "overflow area" that only Apple devices can read — Android/Karoo
        //      goes blind.
        //   2. It isn't needed. Advertising is only for DISCOVERY. Once a central
        //      connects, it can enumerate every service in the GATT database,
        //      waypoint service included.
        //
        // iOS supports only these two advertisement keys. No manufacturer data,
        // no service data — so the waypoint payload can never ride in the
        // advertisement itself; it must travel over GATT after connecting.
        manager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [hrServiceUUID],
            CBAdvertisementDataLocalNameKey: "KarooSend"
        ])
    }

    // MARK: - Heart rate simulation

    /// Karoo will drop a "sensor" that connects and then says nothing, so we
    /// emit plausible readings to hold the connection open.
    private func startHeartRateNotifications() {
        notifyTimer?.invalidate()
        notifyTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) {
            [weak self] _ in
            guard let self else { return }
            self.bpm = 60 + ((self.bpm - 60 + 1) % 40)
            // HR Measurement format: flags byte (0x00 = uint8 BPM) + value.
            let payload = Data([0x00, self.bpm])
            self.manager.updateValue(payload,
                                     for: self.hrCharacteristic,
                                     onSubscribedCentrals: nil)
        }
    }
}

// MARK: - CBPeripheralManagerDelegate

extension KarooSendPeripheral: CBPeripheralManagerDelegate {

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        // Nothing works until state is .poweredOn. Do not advertise before this.
        switch peripheral.state {
        case .poweredOn:
            print("[ble] powered on — building services")
            buildServices()
            startAdvertising()
        case .unauthorized:
            print("[ble] UNAUTHORIZED — check NSBluetoothAlwaysUsageDescription in Info.plist")
        case .poweredOff:
            print("[ble] bluetooth is off")
        case .unsupported:
            print("[ble] unsupported — are you on the Simulator? CoreBluetooth needs a real device.")
        default:
            print("[ble] state: \(peripheral.state.rawValue)")
        }
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager,
                                              error: Error?) {
        if let error {
            print("[ble] advertising FAILED: \(error.localizedDescription)")
        } else {
            print("[ble] ✅ advertising as 'KarooSend' with service UUID 180D in the packet")
            print("[ble] now open Karoo → Settings → Sensors → Add Sensor → Heart Rate")
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           didAdd service: CBService,
                           error: Error?) {
        if let error {
            print("[ble] failed to add \(service.uuid): \(error.localizedDescription)")
        } else {
            print("[ble] added service \(service.uuid)")
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didSubscribeTo characteristic: CBCharacteristic) {
        print("[ble] *** SUBSCRIBED to \(characteristic.uuid) — something connected! ***")
        if characteristic.uuid == hrMeasurementUUID {
            startHeartRateNotifications()
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           central: CBCentral,
                           didUnsubscribeFrom characteristic: CBCharacteristic) {
        print("[ble] unsubscribed from \(characteristic.uuid)")
        if characteristic.uuid == hrMeasurementUUID {
            notifyTimer?.invalidate()
            notifyTimer = nil
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager,
                           didReceiveRead request: CBATTRequest) {
        guard request.characteristic.uuid == waypointCharUUID else {
            peripheral.respond(to: request, withResult: .attributeNotFound)
            return
        }
        print("[ble] waypoint read by central")
        request.value = pendingWaypoint
        peripheral.respond(to: request, withResult: .success)
    }
}
