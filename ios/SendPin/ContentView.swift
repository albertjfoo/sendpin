//
//  ContentView.swift
//  sendpin
//
//  The main screen. Two jobs: tell you what's happening when something is
//  happening, and otherwise stay out of the way while explaining how to set
//  the thing up and use it.
//

import SwiftUI

struct ContentView: View {

    @Bindable var peripheral: SendPinPeripheral
    @State private var showingWelcome = false
    @State private var showingDebug = false

    var body: some View {
        NavigationStack {
            List {
                brandHeader
                if let state = activeState { statusSection(state) }
                destinationSection
                setUpSection
                howToUseSection
                debugSection
            }
            .listSectionSpacing(.compact)
            .navigationTitle("SendPin")
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
                    SetupState.hasSeenWelcome = true
                    showingWelcome = false
                }
            }
            .sheet(isPresented: $showingDebug) {
                DebugView(peripheral: peripheral)
            }
        }
        .onAppear {
            if !SetupState.hasSeenWelcome { showingWelcome = true }
        }
    }

    // MARK: - Header

    private var brandHeader: some View {
        Section {
            HStack(spacing: 14) {
                AppMark(size: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text("SendPin").font(.title3.weight(.semibold))
                    Text("Destinations, phone to Karoo 2")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
    }

    // MARK: - Status
    //
    // Only rendered when there is something to say. An idle "nothing to send"
    // card is noise on a screen someone opens to read the instructions.

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
            case .notPickedUp: .orange
            case .unavailable: .orange
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

    // MARK: - Set up

    private var setUpSection: some View {
        Section("Set up") {
            setUpRow(
                number: 1,
                title: "Add the Shortcut",
                detail: "Puts “Send to Karoo” in the Maps share sheet.",
                url: Links.shortcut,
            )
            setUpRow(
                number: 2,
                title: "Install the Karoo extension",
                detail: "The Karoo needs a small app to receive destinations.",
                url: Links.karooExtension,
            )
        }
    }

    @ViewBuilder
    private func setUpRow(number: Int, title: String, detail: String, url: URL) -> some View {
        if Links.isPlaceholder(url) {
            // Fails visibly rather than opening a dead page.
            HStack(alignment: .top, spacing: 14) {
                StepBadge(number: number)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.body)
                    Label("Link not configured yet", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
            .padding(.vertical, 2)
        } else {
            Link(destination: url) {
                HStack(alignment: .top, spacing: 14) {
                    StepBadge(number: number)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title).font(.body).foregroundStyle(.primary)
                        Text(detail).font(.footnote).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - How to use

    private var howToUseSection: some View {
        Section("How to use") {
            useRow(1, "Find a place in Apple Maps")
            useRow(2, "Share → Send to Karoo")
            useRow(3, "Keep this screen open while it sends")
            useRow(4, "The Karoo shows the pin, ready to navigate")
        }
    }

    private func useRow(_ n: Int, _ text: String) -> some View {
        HStack(spacing: 14) {
            StepBadge(number: n)
            Text(text).font(.body)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Debug

    private var debugSection: some View {
        Section {
            Button { showingDebug = true } label: {
                Label("Connection details", systemImage: "wrench.and.screwdriver")
                    .font(.subheadline)
            }
            Button { showingWelcome = true } label: {
                Label("What is this?", systemImage: "questionmark.circle")
                    .font(.subheadline)
            }
        } header: {
            Text("Debug")
        } footer: {
            Text("Connection details shows the raw Bluetooth log. Useful when reporting a problem.")
        }
    }
}

// MARK: - Debug

/// The raw log, kept out of the main screen. Still the fastest way to answer
/// "why didn't that work" when someone reports a problem.
struct DebugView: View {
    @Bindable var peripheral: SendPinPeripheral
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Bluetooth", value: peripheral.statusText)
                    LabeledContent("Advertising", value: peripheral.isAdvertising ? "Yes" : "No")
                    LabeledContent("Reads by Karoo", value: "\(peripheral.readCount)")
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
