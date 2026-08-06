//
//  Waypoint.swift
//  karoo2-send
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

    /// A one-line summary for the on-screen log.
    var summary: String {
        String(format: "%@ (%.5f, %.5f)", name, lat, lng)
    }
}

extension Waypoint {

    /// Parses the URL a Shortcut hands us:
    ///
    ///     karoosend://send?lat=51.5007&lng=-0.1246&name=Big%20Ben
    ///
    /// Returns nil rather than a partial waypoint — a send with a missing
    /// coordinate would silently navigate you to null island.
    init?(url: URL) {
        guard url.scheme?.lowercased() == "karoosend",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else { return nil }

        // Accept both karoosend://send?… (host == "send") and karoosend:?…
        if let host = components.host, !host.isEmpty, host.lowercased() != "send" {
            return nil
        }

        let items = components.queryItems ?? []
        func value(_ name: String) -> String? {
            items.first { $0.name.lowercased() == name }?.value
        }

        guard let latText = value("lat"), let lat = Double(latText),
              let lngText = value("lng") ?? value("lon") ?? value("long"),
              let lng = Double(lngText)
        else { return nil }

        // Reject out-of-range coordinates here rather than shipping them over
        // BLE for the Karoo to choke on.
        guard (-90...90).contains(lat), (-180...180).contains(lng) else { return nil }

        self.lat = lat
        self.lng = lng
        // Karoo's pin UI has little room, and the name is only a label.
        self.name = (value("name")?.trimmingCharacters(in: .whitespacesAndNewlines))
            .flatMap { $0.isEmpty ? nil : String($0.prefix(64)) } ?? "Destination"
    }
}
