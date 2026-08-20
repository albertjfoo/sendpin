//
//  SettingsView.swift
//  SendPin
//
//  Everything that used to compete for space on the home screen. After the
//  first day none of it matters, so it costs nothing behind a gear.
//

import SwiftUI

struct SettingsView: View {
    var peripheral: SendPinPeripheral
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    /// Clearing this is all it takes to replay the intro — the app shows it
    /// over everything whenever the flag is false, so there is no second copy
    /// of the flow to keep in step.
    @AppStorage(SetupKey.hasSeenWelcome) private var hasSeenWelcome = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("Installation guide") { openURL(Links.site) }
                    Button("Welcome screen") {
                        dismiss()
                        hasSeenWelcome = false
                    }
                    Button("Send feedback") { openURL(Links.feedback) }
                    Button("Source on GitHub") { openURL(Links.karooExtension) }
                }

                Section {
                    NavigationLink("Connection details") { DiagnosticsView(peripheral: peripheral) }
                    LabeledContent("Version", value: Bundle.main.shortVersion)
                } footer: {
                    Text("SendPin is free and open source. Not affiliated with Hammerhead or SRAM.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}

/// The peripheral's own log — the thing to paste into an issue.
struct DiagnosticsView: View {
    var peripheral: SendPinPeripheral

    var body: some View {
        List {
            Section("Bluetooth") {
                LabeledContent("Status", value: peripheral.statusText)
                LabeledContent("Reads", value: "\(peripheral.readCount)")
            }
            Section("Log") {
                if peripheral.log.isEmpty {
                    Text("Nothing yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(peripheral.log) { entry in
                        Text(entry.text).font(.caption.monospaced())
                    }
                }
            }
        }
        .navigationTitle("Connection details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension Bundle {
    var shortVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "—"
    }
}
