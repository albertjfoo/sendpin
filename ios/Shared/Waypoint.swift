//
//  Waypoint.swift
//  sendpin
//
//  The payload. This struct is the wire contract between the iPhone and the
//  Karoo extension — see PROTOCOL.md before changing anything here.
//

import Foundation

/// A destination to send to the Karoo. Mirrors karoo-ext's `Symbol.POI`
/// (`{id, lat, lng, type, name}`), minus the fields the extension fills in.
struct Waypoint: Codable, Equatable {
    var lat: Double
    var lng: Double
    var name: String

    static let none = Waypoint(lat: 0, lng: 0, name: "none")

    /// Wire format: compact UTF-8 JSON, `{"lat":..,"lng":..,"name":".."}`.
    ///
    /// Key order is pinned so the bytes are stable across runs — makes the
    /// hex dumps in nRF Connect and logcat comparable when debugging.
    var encoded: Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        // Encoding a struct of Double/String cannot fail; the fallback keeps
        // the peripheral serving *something* rather than trapping mid-ride.
        return (try? encoder.encode(self)) ?? Data(#"{"lat":0,"lng":0,"name":"error"}"#.utf8)
    }

    /// The bytes actually sent to the Karoo: the waypoint plus the sending
    /// phone's ID, so the Karoo can drop pins from any phone but its paired one.
    ///
    /// A separate wire struct rather than adding `id` to Waypoint itself —
    /// Waypoint is the destination, and the identity of who sent it does not
    /// belong on it. Keys stay sorted so the bytes are stable and hex dumps
    /// remain comparable. Old Karoo firmware ignores the extra key.
    func wireData(deviceID: String) -> Data {
        struct Wire: Encodable { let id: String; let lat: Double; let lng: Double; let name: String }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let wire = Wire(id: deviceID, lat: lat, lng: lng, name: name)
        return (try? encoder.encode(wire)) ?? encoded
    }

    /// A one-line summary for the on-screen log.
    var summary: String {
        String(format: "%@ (%.5f, %.5f)", name, lat, lng)
    }
}

