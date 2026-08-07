//
//  ContentView.swift
//  karoo2-send
//
//  What someone sees after sharing a place from Maps. The job of this screen
//  is to answer one question — has the Karoo got it yet? — and otherwise stay
//  out of the way.
//

import SwiftUI

struct ContentView: View {

    @Bindable var peripheral: KarooSendPeripheral
    @State private var showingSetup = false
    @State private var showingDetails = false

    var body: some View {
        NavigationStack {
            List {
                statusSection
                destinationSection
                helpSection
            }
            .navigationTitle("KarooSend")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Setup") { showingSetup = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if peripheral.isAdvertising {
                        Button("Stop") { peripheral.stop() }
                    }
                }
            }
            .sheet(isPresented: $showingSetup) {
                SetupView { showingSetup = false }
            }
            .sheet(isPresented: $showingDetails) {
                DetailsView(peripheral: peripheral)
            }
        }
        .onAppear {
            if !SetupState.hasSeenSetup {
                showingSetup = true
                SetupState.hasSeenSetup = true
            }
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        Section {
            HStack(spacing: 14) {
                Image(systemName: state.icon)
                    .font(.title2)
                    .foregroundStyle(state.tint)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.title).font(.headline)
                    Text(state.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
    }

    /// One of four things is true, and the screen should say which without the
    /// reader having to interpret a log.
    private enum ScreenState {
        case delivered, sending, idle, unavailable(String)

        var icon: String {
            switch self {
            case .delivered: "checkmark.circle.fill"
            case .sending: "dot.radiowaves.left.and.right"
            case .idle: "location.slash"
            case .unavailable: "exclamationmark.triangle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .delivered: .green
            case .sending: .accentColor
            case .idle: .secondary
            case .unavailable: .orange
            }
        }

        var title: String {
            switch self {
            case .delivered: "Sent to Karoo"
            case .sending: "Sending…"
            case .idle: "Nothing to send"
            case .unavailable: "Bluetooth unavailable"
            }
        }

        var detail: String {
            switch self {
            case .delivered: "Your Karoo has the destination. Check its screen."
            case .sending: "Keep this screen open until the Karoo picks it up."
            case .idle: "Share a place from Maps to send it here."
            case .unavailable(let why): why
            }
        }
    }

    private var state: ScreenState {
        guard peripheral.canAdvertise else {
            return .unavailable(peripheral.statusText)
        }
        if peripheral.isAdvertising { return .sending }
        // Stopped advertising *after* a read means the Karoo took it, which is
        // the peripheral's own auto-stop rather than the user pressing Stop.
        if peripheral.readCount > 0 { return .delivered }
        return .idle
    }

    // MARK: - Destination

    @ViewBuilder
    private var destinationSection: some View {
        if peripheral.waypoint != .none {
            Section("Destination") {
                VStack(alignment: .leading, spacing: 4) {
                    Text(peripheral.waypoint.name)
                        .font(.body.weight(.medium))
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

    // MARK: - Help

    private var helpSection: some View {
        Section {
            Button {
                showingDetails = true
            } label: {
                Label("Connection details", systemImage: "list.bullet.rectangle")
            }
            Button {
                showingSetup = true
            } label: {
                Label("Setup instructions", systemImage: "questionmark.circle")
            }
        } footer: {
            Text("Share a place from Maps and choose the KarooSend shortcut. This app opens, sends the destination, and stops by itself.")
        }
    }
}

// MARK: - Details

/// The old debug console, kept but moved out of the way. Still the fastest way
/// to answer "why didn't that work" when someone reports a problem.
struct DetailsView: View {
    @Bindable var peripheral: KarooSendPeripheral
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
            .navigationTitle("Details")
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
