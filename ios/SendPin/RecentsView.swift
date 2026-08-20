//
//  RecentsView.swift
//  SendPin
//
//  Everything sent, grouped by when. Clearing a group leaves pins alone —
//  a pin is something you chose to keep, and it only appears here because it
//  was sent at some point.
//

import SwiftUI

struct RecentsView: View {
    var store: SendStore
    var onSend: (Place) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Place?

    private struct Group: Identifiable {
        var id: String { title }
        let title: String
        let places: [Place]
    }

    private var groups: [Group] {
        let calendar = Calendar.current
        let all = store.places.sorted { $0.lastSent > $1.lastSent }
        var today: [Place] = [], month: [Place] = [], older: [Place] = []
        for place in all {
            if calendar.isDateInToday(place.lastSent) { today.append(place) }
            else if calendar.isDate(place.lastSent, equalTo: .now, toGranularity: .month) { month.append(place) }
            else { older.append(place) }
        }
        return [Group(title: "Today", places: today),
                Group(title: "This month", places: month),
                Group(title: "Earlier", places: older)]
            .filter { !$0.places.isEmpty }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups) { group in
                    Section {
                        ForEach(group.places) { place in
                            PlaceRow(place: place,
                                     onSend: { dismiss(); onSend(place) },
                                     onOpen: { selected = place })
                        }
                    } header: {
                        HStack {
                            Text(group.title)
                            Spacer()
                            // Only offered when there is something clearable —
                            // a group of nothing but pins would do nothing.
                            if group.places.contains(where: { !$0.pinned }) {
                                Button("Clear") { store.clear(group.places) }
                                    .font(.subheadline.weight(.semibold))
                                    .textCase(nil)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Recents")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Close")
                }
            }
            .sheet(item: $selected) { place in
                PlaceSheet(place: place, store: store) { onSend(place) }
            }
        }
    }
}

/// Pick something already sent and pin it. The app has no search of its own,
/// so history is the only place a pin can come from.
struct AddPinView: View {
    var store: SendStore
    @Environment(\.dismiss) private var dismiss

    /// Already-pinned places are not offered — picking one would silently
    /// unpin it, which is the opposite of what this screen is for.
    private var candidates: [Place] { store.recents.filter { !$0.pinned } }

    var body: some View {
        NavigationStack {
            Group {
                if candidates.isEmpty {
                    ContentUnavailableView("Nothing to pin",
                                           systemImage: "mappin.slash",
                                           description: Text(store.recents.isEmpty
                                                             ? "Send a place from Apple Maps and it will show up here."
                                                             : "Everything you have sent is already pinned."))
                } else {
                    List {
                        Section("Recent") {
                            ForEach(candidates) { place in
                                Button {
                                    store.togglePin(place)
                                    dismiss()
                                } label: {
                                    HStack(spacing: 11) {
                                        Image(systemName: place.glyph)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                            .frame(width: 33, height: 33)
                                            .background(Color(.systemGray6), in: Circle())
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(place.name).font(.subheadline.weight(.semibold))
                                            if let subtitle = place.subtitle {
                                                Text(subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                            }
                                        }
                                        Spacer()
                                        Image(systemName: "pin").foregroundStyle(Color.accentColor)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Pin")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
    }
}
