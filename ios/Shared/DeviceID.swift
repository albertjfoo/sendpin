//
//  DeviceID.swift
//  Shared
//
//  A stable name for this phone, so a Karoo can tell one sender from another.
//
//  Generated once and kept in the App Group, which is what makes the app and
//  the share extension — two processes — agree on the same ID rather than each
//  minting its own. The Karoo pairs to the first ID it hears and ignores the
//  rest, so two SendPin users at the same table no longer land pins on each
//  other's head unit.
//
//  Deliberately not the identifierForVendor: that changes if every app from
//  this vendor is deleted, and it is Apple's to reset. This is our own value,
//  reset only by deleting the app, which is exactly the lifetime we want — a
//  reinstall *should* look like a new phone to a Karoo it was paired with, and
//  the Karoo's "Forget iPhone" is how you re-pair.
//
//  Sixteen hex characters (8 random bytes). Not a full UUID: the job is to
//  distinguish the handful of phones near one Karoo, not to be globally unique,
//  and every byte here is a byte added to a BLE payload with a real size budget.
//

import Foundation

enum DeviceID {
    private static let key = "deviceID"

    static let current: String = {
        let store = UserDefaults(suiteName: SendStore.groupID) ?? .standard
        if let existing = store.string(forKey: key) { return existing }
        let id = randomHex(bytes: 8)
        store.set(id, forKey: key)
        return id
    }()

    private static func randomHex(bytes count: Int) -> String {
        var data = Data(count: count)
        _ = data.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, count, $0.baseAddress!) }
        return data.map { String(format: "%02x", $0) }.joined()
    }
}
