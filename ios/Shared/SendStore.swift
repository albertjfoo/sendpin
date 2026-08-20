//
//  SendStore.swift
//  SendPin
//
//  Every place that has been sent, and which of them are pinned.
//
//  Lives in the App Group container because most sends happen in the share
//  extension, which is a separate process with its own sandbox. Without the
//  shared container the app's history would be empty for the one flow people
//  actually use.
//
//  Plain JSON on disk rather than a database: the file is a few kilobytes, both
//  processes need it, and a widget will need it later. Nothing here is worth a
//  schema migration.
//

import Foundation

/// A place that has been sent at least once.
struct Place: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var subtitle: String?
    var lat: Double
    var lng: Double
    var pinned: Bool = false
    var lastSent: Date
    var sendCount: Int = 1
    /// The glyph Maps would show for this kind of place. Optional so records
    /// written before this existed still decode.
    var symbol: String?

    /// Never nil at the point of drawing — an unclassified place is a pin.
    var glyph: String { symbol ?? PlaceSymbol.fallback }

    var waypoint: Waypoint { Waypoint(lat: lat, lng: lng, name: name) }

    /// Two sends of the same café are the same place, even when Maps hands over
    /// coordinates that differ in the sixth decimal. ~11 m at five decimals.
    func matches(lat other: Double, lng otherLng: Double, name otherName: String) -> Bool {
        abs(lat - other) < 0.0001 && abs(lng - otherLng) < 0.0001 && name == otherName
    }
}

@Observable
final class SendStore {
    static let groupID = "group.com.albert.sendpin"
    static let shared = SendStore()

    private(set) var places: [Place] = []

    /// Pinned first, then the rest by recency — the order the home screen wants.
    var pinned: [Place] { places.filter(\.pinned).sorted { $0.lastSent > $1.lastSent } }
    /// Everything, newest first. Pinning is a shortcut, not a move — a pinned
    /// place is still something you sent and still belongs in the history.
    var recents: [Place] { places.sorted { $0.lastSent > $1.lastSent } }
    var isEmpty: Bool { places.isEmpty }

    private let url: URL?

    init() {
        url = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: Self.groupID)?
            .appendingPathComponent("places.json")
        load()
    }

    // MARK: - Reading and writing

    func load() {
        guard let url, let data = try? Data(contentsOf: url) else { return }
        places = (try? JSONDecoder().decode([Place].self, from: data)) ?? []
    }

    private func save() {
        guard let url, let data = try? JSONEncoder().encode(places) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Changes

    /// Record a send. Called from the share extension as well as the app, so it
    /// merges rather than always inserting.
    @discardableResult
    func record(name: String, subtitle: String?, lat: Double, lng: Double,
                symbol: String? = nil) -> Place {
        load()   // another process may have written since we last looked
        if let i = places.firstIndex(where: { $0.matches(lat: lat, lng: lng, name: name) }) {
            places[i].lastSent = .now
            places[i].sendCount += 1
            if let subtitle, places[i].subtitle == nil { places[i].subtitle = subtitle }
            // Backfills places recorded before categories were stored.
            if let symbol, places[i].symbol == nil { places[i].symbol = symbol }
            save()
            return places[i]
        }
        let place = Place(name: name, subtitle: subtitle, lat: lat, lng: lng,
                          lastSent: .now, symbol: symbol)
        places.insert(place, at: 0)
        save()
        return place
    }

    func togglePin(_ place: Place) {
        guard let i = places.firstIndex(where: { $0.id == place.id }) else { return }
        places[i].pinned.toggle()
        save()
    }

    func remove(_ place: Place) {
        places.removeAll { $0.id == place.id }
        save()
    }

    /// Clearing history never removes a pin — a pin is a thing you chose to
    /// keep, and it is only in this list because it was sent at some point.
    func clear(_ toClear: [Place]) {
        let ids = Set(toClear.filter { !$0.pinned }.map(\.id))
        places.removeAll { ids.contains($0.id) }
        save()
    }
}
