//
//  PlaceViews.swift
//  SendPin
//
//  The pieces the home screen is built from: a pinned bubble, a history row,
//  and the sheet that opens when you tap one.
//

import SwiftUI

/// A pinned place in the grid.
///
/// Four to a row, which keeps the discs close together the way the old strip
/// did. Names truncate rather than wrap, the way Apple Maps does — a grid row
/// centres its cells, so one wrapping name lifted its own disc out of line with
/// the rest of the row.
///
/// The long press is a real context menu, the way Apple Maps does it: the disc
/// lifts and enlarges, the phone taps back, and the menu appears beside it.
///
/// That only works because the home screen is a ScrollView. A context menu
/// declared inside a List row is hoisted to the row itself, and a row holds one
/// — so every pin in the grid opened the first pin's menu and unpinned it.
struct PinBubble: View {
    var place: Place
    var onSend: () -> Void
    var onOpen: () -> Void
    var onUnpin: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            // The same glyph the history row shows, so a pin and its row
            // are recognisably one place.
            Image(systemName: place.glyph)
                .font(.title2)
                .foregroundStyle(Brand.ink)
                .frame(width: 62, height: 62)
                .background(Brand.yellow, in: Circle())
            Text(place.name)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSend)
        .contextMenu {
            Button("Open options", systemImage: "ellipsis.circle", action: onOpen)
            Button("Unpin", systemImage: "pin.slash", role: .destructive, action: onUnpin)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Send \(place.name) to Karoo")
    }
}

/// The last cell in the grid.
struct AddPinBubble: View {
    var action: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.title2)
                .foregroundStyle(.secondary)
                .frame(width: 62, height: 62)
                .background(Color(.systemGray5), in: Circle())
            Text("Add")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
        .accessibilityLabel("Add a pin")
    }
}

/// A history row. The row opens options; the circle sends straight away.
struct PlaceRow: View {
    var place: Place
    var onSend: () -> Void
    var onOpen: () -> Void

    var body: some View {
        HStack(spacing: 11) {
            Button(action: onOpen) {
                HStack(spacing: 11) {
                    Image(systemName: place.glyph)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(width: 33, height: 33)
                        .background(Color(.systemGray6), in: Circle())
                    VStack(alignment: .leading, spacing: 1) {
                        Text(place.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Text(place.lastSent, format: .relative(presentation: .named))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            // Deliberately a separate target: tapping the row should never
            // start a broadcast by accident.
            Button(action: onSend) {
                // Yellow is the send colour throughout the app now — the pill
                // that broadcasts the pin is always this yellow with ink on it.
                SendGlyph(size: 14)
                    .foregroundStyle(Brand.ink)
                    .frame(width: 30, height: 30)
                    .background(Brand.yellow, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Send \(place.name) to Karoo")
        }
        // 11 + 3. An inset-grouped List row adds ~11pt of its own padding
        // around the content, which vanished when the home screen stopped
        // being a List; the original 3 was on top of that.
        .padding(.vertical, 14)
    }
}

/// Options for one place.
struct PlaceSheet: View {
    var place: Place
    var store: SendStore
    var onSend: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // No mark and no glyph: the place name is the only thing worth
            // reading here, and this sheet now matches the one the share
            // extension shows when a send comes from Apple Maps.
            VStack(spacing: 4) {
                Text(place.name)
                    .font(.title3.weight(.bold))
                    .multilineTextAlignment(.center)
                if let subtitle = place.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .padding(.bottom, 22)

            VStack(spacing: 10) {
                Button { dismiss(); onSend() } label: {
                    HStack(spacing: 8) {
                        SendGlyph(size: 16)
                        Text("Send to Karoo")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Brand.yellow, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .foregroundStyle(Brand.ink)
                }

                Button {
                    store.togglePin(place); dismiss()
                } label: {
                    Text(place.pinned ? "Unpin" : "Pin to top").sheetSecondary()
                }

                Button(role: .destructive) {
                    store.remove(place); dismiss()
                } label: {
                    Text("Remove from history").sheetSecondary()
                }
            }

        }
        .padding(.top, 26)
        .padding(.horizontal, 18)
        .padding(.bottom, 12)
        .fitSheetToContent(estimate: 300)
    }
}
