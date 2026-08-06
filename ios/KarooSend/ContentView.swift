//
//  ContentView.swift
//  karoo2-send
//
//  The log on this screen is not a nicety. Testing means standing over the
//  Karoo with the iPhone in hand, well away from the Xcode console, so
//  everything worth knowing has to be visible on the phone itself.
//

import SwiftUI

struct ContentView: View {

    @Bindable var peripheral: KarooSendPeripheral

    @State private var latText = ""
    @State private var lngText = ""
    @State private var nameText = ""

    var body: some View {
        NavigationStack {
            Form {
                statusSection
                modeSection
                if peripheral.mode == .waypoint {
                    destinationSection
                }
                logSection
            }
            .navigationTitle("KarooSend")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(peripheral.isAdvertising ? "Stop" : "Start") {
                        peripheral.isAdvertising ? peripheral.stop() : peripheral.start()
                    }
                    .disabled(!peripheral.canAdvertise)
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Sections

    private var statusSection: some View {
        Section {
            LabeledContent("Status") {
                HStack(spacing: 6) {
                    Circle()
                        .fill(peripheral.isAdvertising ? .green : .secondary)
                        .frame(width: 8, height: 8)
                    Text(peripheral.statusText)
                }
            }
            if peripheral.isAdvertising {
                LabeledContent("Subscribers", value: "\(peripheral.subscriberCount)")
                LabeledContent("Waypoint reads", value: "\(peripheral.readCount)")
            }
        } footer: {
            if peripheral.managerState == .unsupported {
                Text("CoreBluetooth is unavailable. This app has to run on a physical iPhone — the Simulator cannot advertise.")
            } else if peripheral.managerState == .unauthorized {
                Text("Grant Bluetooth access in Settings → KarooSend.")
            } else {
                Text("Keep this screen open while sending. iOS hides the service UUID from non-Apple devices as soon as the app backgrounds.")
            }
        }
    }

    private var modeSection: some View {
        Section {
            Picker("Mode", selection: $peripheral.mode) {
                ForEach(AdvertisingMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
        } footer: {
            Text(peripheral.mode.explanation)
        }
    }

    private var destinationSection: some View {
        Section("Destination") {
            LabeledContent("Current", value: peripheral.waypoint.summary)
                .font(.footnote)
                .foregroundStyle(.secondary)

            TextField("Latitude", text: $latText)
                .keyboardType(.numbersAndPunctuation)
            TextField("Longitude", text: $lngText)
                .keyboardType(.numbersAndPunctuation)
            TextField("Name", text: $nameText)

            Button("Set destination", action: applyManualDestination)
                .disabled(manualWaypoint == nil)
        }
    }

    private var logSection: some View {
        Section {
            if peripheral.log.isEmpty {
                Text("No events yet.")
                    .foregroundStyle(.secondary)
            } else {
                // Newest first: the interesting line is always the last thing
                // that happened, and scrolling a Form to the bottom mid-test is
                // exactly the fiddling this screen exists to avoid.
                ForEach(peripheral.log.reversed()) { entry in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(entry.date, format: .dateTime.hour().minute().second())
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Text(entry.text)
                            .font(.caption)
                            .foregroundStyle(color(for: entry.level))
                    }
                }
            }
        } header: {
            HStack {
                Text("Log")
                Spacer()
                Button("Clear", action: peripheral.clearLog)
                    .font(.caption)
                    .textCase(nil)
            }
        }
    }

    // MARK: - Helpers

    /// nil until every field parses, which is also what disables the button.
    private var manualWaypoint: Waypoint? {
        guard let lat = Double(latText.trimmingCharacters(in: .whitespaces)),
              let lng = Double(lngText.trimmingCharacters(in: .whitespaces)),
              (-90...90).contains(lat), (-180...180).contains(lng)
        else { return nil }

        let trimmed = nameText.trimmingCharacters(in: .whitespacesAndNewlines)
        return Waypoint(lat: lat, lng: lng, name: trimmed.isEmpty ? "Destination" : trimmed)
    }

    private func applyManualDestination() {
        guard let waypoint = manualWaypoint else { return }
        peripheral.send(waypoint)
    }

    private func color(for level: PeripheralLogEntry.Level) -> Color {
        switch level {
        case .info: .primary
        case .success: .green
        case .warning: .orange
        case .failure: .red
        }
    }
}

#Preview {
    ContentView(peripheral: KarooSendPeripheral())
}
