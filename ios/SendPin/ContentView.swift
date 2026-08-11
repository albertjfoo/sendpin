//
//  ContentView.swift
//  sendpin
//
//  The main screen. Fixed layout: setup, then how to use, then debug. Ticking
//  the last setup box announces itself in place rather than rearranging the
//  screen underneath you.
//

import SwiftUI

struct ContentView: View {

    @Bindable var peripheral: SendPinPeripheral

    @AppStorage(SetupKey.hasSeenWelcome) private var hasSeenWelcome = false
    @AppStorage(SetupKey.shortcutAdded) private var shortcutAdded = false
    @AppStorage(SetupKey.extensionInstalled) private var extensionInstalled = false

    @State private var showingWelcome = false
    @State private var showingConnectionDetails = false

    private var setupComplete: Bool { shortcutAdded && extensionInstalled }

    var body: some View {
        NavigationStack {
            List {
                brandHeader
                if let state = activeState { statusSection(state) }
                destinationSection

                // Deliberately a fixed order. Rearranging the screen under
                // someone the moment they tick the last box is disorienting —
                // the thing they were looking at moves. Completion is announced
                // instead, in place.
                mainCards

                helpSection
            }
            .animation(.default, value: setupComplete)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if peripheral.isAdvertising {
                        Button("Stop") { peripheral.stop() }
                    }
                }
            }
            .sheet(isPresented: $showingWelcome) {
                WelcomeView {
                    hasSeenWelcome = true
                    showingWelcome = false
                }
            }
            .sheet(isPresented: $showingConnectionDetails) {
                ConnectionDetailsView(peripheral: peripheral)
            }
        }
        .onAppear {
            if !hasSeenWelcome { showingWelcome = true }
        }
    }

    // MARK: - Header
    //
    // Centred masthead, deliberately not a card: no background, no separator,
    // no chevron. A left-aligned row inside a grouped list reads as something
    // you can tap, which is exactly what it is not.

    private var brandHeader: some View {
        Section {
            VStack(spacing: 10) {
                AppMark(size: 68)
                Text("SendPin").font(.title2.weight(.semibold))
                Text("Send a destination from your iPhone to your Karoo 2.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 20)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
            .padding(.bottom, 0)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    // MARK: - Status
    //
    // Only rendered when there is something to say.

    private enum ScreenState {
        case delivered, sending, notPickedUp, unavailable(String)

        var icon: String {
            switch self {
            case .delivered: "checkmark.circle.fill"
            case .sending: "dot.radiowaves.left.and.right"
            case .notPickedUp: "questionmark.circle.fill"
            case .unavailable: "exclamationmark.triangle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .delivered: .green
            case .sending: .blue
            case .notPickedUp, .unavailable: .orange
            }
        }

        var title: String {
            switch self {
            case .delivered: "Sent to Karoo"
            case .sending: "Sending…"
            case .notPickedUp: "Nothing picked this up"
            case .unavailable: "Bluetooth unavailable"
            }
        }

        var detail: String {
            switch self {
            case .delivered: "Your Karoo has the destination. Check its screen."
            case .sending: "Keep this screen open until the Karoo picks it up."
            case .notPickedUp: "Still broadcasting. Open SendPin on the Karoo and check it says \"listening\"."
            case .unavailable(let why): why
            }
        }
    }

    private var activeState: ScreenState? {
        guard peripheral.canAdvertise else { return .unavailable(peripheral.statusText) }
        if peripheral.isAdvertising {
            return peripheral.noResponseYet ? .notPickedUp : .sending
        }
        if peripheral.readCount > 0 { return .delivered }
        return nil
    }

    private func statusSection(_ state: ScreenState) -> some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: state.icon)
                    .font(.title2)
                    .foregroundStyle(state.tint)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.title).font(.headline)
                    Text(state.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Destination

    @ViewBuilder
    private var destinationSection: some View {
        if peripheral.waypoint != .none {
            Section("Destination") {
                VStack(alignment: .leading, spacing: 3) {
                    Text(peripheral.waypoint.name).font(.body.weight(.medium))
                    Text(peripheral.waypoint.summary)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)

                if !peripheral.isAdvertising {
                    Button("Send again") { peripheral.send(peripheral.waypoint) }
                }
            }
        }
    }

    // MARK: - Set up and how to use
    //
    // Two cards of the same shape. One leads to a checklist, the other to
    // instructions; neither should look more important than the other by
    // accident, so they share NavCard.

    /// One section, so the two sit together rather than being separated by a
    /// full section gap. They are a pair, not two unrelated things.
    private var mainCards: some View {
        Section {
            NavigationLink {
                SetupChecklistView()
            } label: {
                NavCard(
                    icon: .symbol("checklist"),
                    title: "Set up",
                    subtitle: setupComplete
                        ? "Shortcut and extension installed"
                        : "Add the Shortcut and Karoo extension",
                    done: setupComplete,
                )
            }

            NavigationLink {
                HowToUseView()
            } label: {
                NavCard(
                    icon: .asset("SendGlyph"),
                    title: "How to use",
                    subtitle: "Share a place from Maps and send it",
                )
            }
        }
    }

    // MARK: - Help

    private var helpSection: some View {
        Section {
            Button { showingConnectionDetails = true } label: {
                Label("Connection details", systemImage: "wrench.and.screwdriver")
                    .font(.subheadline)
            }
            Button { showingWelcome = true } label: {
                Label("What is this?", systemImage: "questionmark.circle")
                    .font(.subheadline)
            }
        } header: {
            Text("Help")
        }
    }
}

// MARK: - Connection details

/// The raw log, kept off the main screen. Still the fastest way to answer
/// "why didn't that work" when someone reports a problem.
struct ConnectionDetailsView: View {
    @Bindable var peripheral: SendPinPeripheral
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Bluetooth", value: peripheral.statusText)
                    LabeledContent("Advertising", value: peripheral.isAdvertising ? "Yes" : "No")
                    LabeledContent("Reads by Karoo", value: "\(peripheral.readCount)")
                } footer: {
                    Text("The raw Bluetooth log. Worth including when reporting a problem.")
                }

                Section("Log") {
                    if peripheral.log.isEmpty {
                        Text("Nothing yet.").foregroundStyle(.secondary)
                    }
                    // Newest first: the interesting line is the one that just
                    // happened, and scrolling to the bottom mid-test is awkward
                    // when you are standing over the bike.
                    ForEach(peripheral.log.reversed()) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.text)
                                .font(.footnote)
                                .foregroundStyle(entry.level.tint)
                            Text(entry.date, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .navigationTitle("Connection details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Clear", action: peripheral.clearLog)
                }
            }
        }
    }
}

private extension PeripheralLogEntry.Level {
    var tint: Color {
        switch self {
        case .info: .primary
        case .success: .green
        case .warning: .orange
        case .failure: .red
        }
    }
}
