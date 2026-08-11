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
    @State private var showingDebug = false

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
                setUpSection
                howToUseCard

                debugSection
            }
            .animation(.default, value: setupComplete)
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
                    hasSeenWelcome = true
                    showingWelcome = false
                }
            }
            .sheet(isPresented: $showingDebug) {
                DebugView(peripheral: peripheral)
            }
        }
        .onAppear {
            if !hasSeenWelcome { showingWelcome = true }
        }
    }

    // MARK: - Header
    //
    // Deliberately not a card: a plain row with no background and no separator,
    // so it does not read as something you can tap. It is a masthead, not a
    // control.

    private var brandHeader: some View {
        Section {
            HStack(spacing: 14) {
                AppMark(size: 48)
                Text("Destinations, phone to Karoo 2")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 2)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
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

    // MARK: - Set up

    private var setUpSection: some View {
        Section {
            setUpRow(
                title: "Add the Shortcut",
                detail: "Puts “Send to Karoo” in the Maps share sheet.",
                url: Links.shortcut,
                done: $shortcutAdded,
            )
            setUpRow(
                title: "Install the Karoo extension",
                detail: "The Karoo needs a small app to receive destinations.",
                url: Links.karooExtension,
                done: $extensionInstalled,
            )

            if setupComplete { completionPrompt }
        } header: {
            Text("Set up")
        } footer: {
            Text("Tap a step to open it, then tick it off. Nothing works until both are done.")
        }
    }

    /// Appears in place when the last box is ticked, pointing at what to do
    /// next rather than silently rearranging the screen.
    private var completionPrompt: some View {
        NavigationLink {
            HowToUseView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Setup complete").font(.subheadline.weight(.semibold))
                    Text("Next: how to send a place")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 3)
        }
        .transition(.opacity)
    }

    /// Tapping the row opens the link; the circle marks it done.
    ///
    /// The tick is user-asserted — the phone cannot verify that a Shortcut was
    /// added or an extension installed, so this records intent rather than
    /// fact. It is only here to decide which section leads the screen.
    @ViewBuilder
    private func setUpRow(title: String, detail: String, url: URL, done: Binding<Bool>) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Button {
                done.wrappedValue.toggle()
            } label: {
                Image(systemName: done.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(done.wrappedValue ? Color.green : Color.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(done.wrappedValue ? "Mark \(title) not done" : "Mark \(title) done")

            if Links.isPlaceholder(url) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.body)
                    Label("Link not configured yet", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            } else {
                Link(destination: url) {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text(detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "arrow.up.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 3)
    }


    // MARK: - How to use

    private var howToUseCard: some View {
        Section {
            NavigationLink {
                HowToUseView()
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "paperplane.fill")
                        .font(.title3)
                        .foregroundStyle(Brand.ink)
                        .frame(width: 40, height: 40)
                        .background(Brand.yellow, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("How to use").font(.headline)
                        Text("Share a place from Maps and send it")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
        }
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

/// The raw log, kept off the main screen. Still the fastest way to answer
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
