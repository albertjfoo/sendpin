//
//  Destination.swift
//  SendPinShare
//
//  Pulling a place out of an Apple Maps share link.
//
//  Deliberately separate from the app's own Waypoint type. They face opposite
//  directions: this parses Apple's URLs, Waypoint parses ours. Sharing one type
//  across both would couple the share sheet to the Bluetooth payload for no
//  gain.
//
//  This replaces two regexes that lived in a Shortcut, where a typo produced a
//  literal "[lat]" in the URL and nothing said so until the app rejected it.
//

import CoreLocation
import Foundation

struct Destination {
    let latitude: Double
    let longitude: Double
    let name: String?

    init(latitude: Double, longitude: Double, name: String?) {
        self.latitude = latitude
        self.longitude = longitude
        self.name = name
    }

    /// Parses the forms Apple Maps actually shares.
    ///
    /// Coordinates travel under different keys depending on the place and iOS
    /// version — `coordinate`, `ll`, `sll`, `q` — so rather than guess, take
    /// the first `lat,lng` pair that appears and is in range. That survived
    /// every real share URL tested.
    init?(mapsURL url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let items = components.queryItems ?? []

        func value(_ names: Set<String>) -> String? {
            items.first { names.contains($0.name.lowercased()) }?.value
        }

        var found: (Double, Double)?
        for key in ["coordinate", "ll", "sll", "q", "daddr"] {
            if let raw = value([key]), let pair = Self.coordinatePair(in: raw) {
                found = pair
                break
            }
        }
        // Some links carry the pair in the path instead — Google Maps writes
        // /@lat,lng,17z. Only the path, never the whole URL: a query string can
        // hold a map span (spn=0.01,0.01) which is a perfectly valid-looking
        // coordinate off the coast of Africa. Sending someone there quietly is
        // worse than admitting we found nothing.
        if found == nil { found = Self.coordinatePair(in: url.path) }

        guard let (lat, lng) = found else { return nil }
        latitude = lat
        longitude = lng

        let rawName = value(["name", "q"])?
            .replacingOccurrences(of: "+", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // A `q` holding coordinates is not a name.
        name = (rawName?.isEmpty == false && Self.coordinatePair(in: rawName!) == nil) ? rawName : nil
    }

    /// First in-range `lat,lng` in a string. Range-checking is what stops a
    /// version number or a zoom level being mistaken for a location.
    private static func coordinatePair(in text: String) -> (Double, Double)? {
        let pattern = #"(-?\d{1,3}\.\d+)\s*,\s*(-?\d{1,3}\.\d+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, range: range) {
            guard let latRange = Range(match.range(at: 1), in: text),
                  let lngRange = Range(match.range(at: 2), in: text),
                  let lat = Double(text[latRange]),
                  let lng = Double(text[lngRange]),
                  CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: lat, longitude: lng))
            else { continue }
            return (lat, lng)
        }
        return nil
    }

    /// What actually gets advertised. An unnamed place still needs a label,
    /// because the Karoo shows the name on its pin screen.
    var waypoint: Waypoint {
        Waypoint(lat: latitude, lng: longitude, name: name ?? "Dropped pin")
    }

    /// The URL form, still used by the Shortcut and by the checks in Tests/.
    /// The share extension no longer goes through it — it advertises directly.
    var sendPinURL: URL? {
        var components = URLComponents()
        components.scheme = "sendpin"
        components.host = "send"
        components.queryItems = [
            URLQueryItem(name: "lat", value: String(latitude)),
            URLQueryItem(name: "lng", value: String(longitude)),
        ]
        if let name { components.queryItems?.append(URLQueryItem(name: "name", value: name)) }
        return components.url
    }
}
