//
//  ContentView.swift
//  SendPin
//
//  Home: what you've sent, and a way to send it again.
//
//  The app used to be a manual — set up, how to use, what is this. The website
//  explains all of that better, and the share extension does the sending, so
//  what's left that only the app can do is remember. Hence a list.
//

import SwiftUI

struct ContentView: View {
    var peripheral: SendPinPeripheral

    @State private var store = SendStore.shared
    @State private var selected: Place?
    @State private var sending: Place?
    @State private var showAddPin = false
    @State private var showSettings = false
    @State private var showShare = false
    @State private var showRecents = false

    @Environment(\.scenePhase) private var scenePhase

    /// Only the first three; the rest live behind Recents.
    private var topRecents: [Place] { Array(store.recents.prefix(3)) }

    /// Pinning is meant to be a shortlist. Eight is the cap, and the grid grows
    /// a second row only when there is something to put in it.
    private static let pinLimit = 8
    private var pins: [Place] { Array(store.pinned.prefix(Self.pinLimit)) }

    /// Four across: three left the discs floating far apart, and the old
    /// horizontal strip's tighter rhythm was the thing worth keeping.
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)

    var body: some View {
        NavigationStack {
            Group {
                if store.isEmpty { emptyState } else { list }
            }
            // Empty, because the mark and the word are one leading item: the
            // navigation title sits wherever the bar puts it, which left a gap
            // between the icon and the name that could not be closed.
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // iOS 26 wraps toolbar items in a glass capsule, which made the
                // mark look like a button. It is decoration, so drop the
                // background where the API exists.
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .topBarLeading) { wordmark }
                        .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarLeading) { wordmark }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showShare = true } label: { Image(systemName: "square.and.arrow.up") }
                        .accessibilityLabel("Share SendPin")
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings")
                }
            }
        }
        // The share extension writes history in another process, so refresh
        // whenever we come back to the foreground.
        .onChange(of: scenePhase) { _, phase in if phase == .active { store.load() } }
        .sheet(item: $selected) { place in
            PlaceSheet(place: place, store: store) { sending = place }
        }
        .sheet(item: $sending) { place in
            SendingSheet(place: place, peripheral: peripheral)
        }
        .sheet(isPresented: $showRecents) {
            RecentsView(store: store) { sending = $0 }
        }
        .sheet(isPresented: $showAddPin) { AddPinView(store: store) }
        .sheet(isPresented: $showSettings) { SettingsView(peripheral: peripheral) }
        .sheet(isPresented: $showShare) { ShareAppView() }
    }

    private var wordmark: some View {
        HStack(spacing: 7) {
            AppMark(size: 26)
            Text("SendPin").font(.headline.weight(.bold)).foregroundStyle(.primary)
        }
        // The bar offers a leading item far less width than the name needs and
        // truncates it to "S". fixedSize makes the text keep its ideal width.
        .fixedSize()
        .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Populated

    // A ScrollView rather than a List. The grouped look is hand-built here,
    // which costs a few lines and buys two things a List cannot give: a context
    // menu that belongs to the pin you pressed, and padding that is the same at
    // the top and the bottom of a card.
    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    header("Pinned")
                    card(insets: EdgeInsets(top: 14, leading: 10, bottom: 14, trailing: 10)) {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 15) {
                            ForEach(pins) { place in
                                PinBubble(place: place,
                                          onSend: { sending = place },
                                          onOpen: { selected = place },
                                          onUnpin: { store.togglePin(place) })
                            }
                            if store.pinned.count < Self.pinLimit {
                                AddPinBubble { showAddPin = true }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        header("Recent")
                        Spacer()
                        if !store.recents.isEmpty {
                            Button("See all") { showRecents = true }
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    card(insets: EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16)) {
                        VStack(spacing: 0) {
                            ForEach(Array(topRecents.enumerated()), id: \.element.id) { index, place in
                                if index > 0 {
                                    Divider().padding(.leading, 44)
                                }
                                PlaceRow(place: place,
                                         onSend: { sending = place },
                                         onOpen: { selected = place })
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func header(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.leading, 4)
    }

    private func card<Content: View>(insets: EdgeInsets,
                                     @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(insets)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)
            AppMark(size: 64)
            Text("Send Your First Pin")
                .font(.title3.weight(.bold))
                .padding(.top, 16)
            Text("Find a place in Apple Maps, tap Share, then SendPin. Everything you send shows up here, ready to send again.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 6)
                .padding(.horizontal, 34)
            Spacer()
        }
    }
}
