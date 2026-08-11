//
//  Setup.swift
//  sendpin
//
//  Onboarding, and the handful of URLs it points at.
//

import SwiftUI

// MARK: - Links

/// Everything the app links out to, in one place.
///
/// ⚠️ These are placeholders until the GitHub Pages site exists. Fill them in
/// before shipping — `SetupView` shows a warning in place of any link still
/// pointing at example.com, so a missed one fails loudly instead of sending
/// someone to a dead page.
enum Links {
    /// The Shortcut, shared from the Shortcuts app via Share → Copy iCloud Link.
    /// Must be an iCloud link: a .shortcut file downloaded from GitHub cannot be
    /// installed directly on iOS.
    static let shortcut = URL(string: "https://www.icloud.com/shortcuts/6aacca931a7d41d8b4f7821992f96256")!

    /// The project page carrying the Karoo APK and install instructions.
    static let karooExtension = URL(string: "https://example.com/karoo")!

    /// Landing page, for the QR code and general help.
    static let home = URL(string: "https://example.com")!

    static func isPlaceholder(_ url: URL) -> Bool {
        url.host?.contains("example.com") ?? true
    }
}

// MARK: - Onboarding state

/// Whether setup has been dismissed. Deliberately *not* a record of whether
/// setup was completed — the app cannot verify that the Shortcut was added or
/// the Karoo extension installed, and pretending otherwise would mean nagging
/// people who are already done.
enum SetupState {
    private static let key = "hasSeenSetup"

    static var hasSeenSetup: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}

// MARK: - Setup view

struct SetupView: View {
    var onDone: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Send destinations to your Karoo 2")
                            .font(.title3.weight(.semibold))
                        Text("Share a place from Maps and it opens on your Karoo, ready to navigate. No internet needed on the Karoo.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }

                step(
                    number: 1,
                    title: "Add the Shortcut",
                    detail: "Lets you share a place straight from Maps. Tap to add it, then allow it when iOS asks.",
                    label: "Get the Shortcut",
                    url: Links.shortcut,
                )

                step(
                    number: 2,
                    title: "Install the Karoo extension",
                    detail: "The Karoo needs a small app to receive destinations. Instructions are on the project page.",
                    label: "Open instructions",
                    url: Links.karooExtension,
                )

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Keep this app open when sending", systemImage: "iphone")
                            .font(.subheadline.weight(.medium))
                        Text("iPhones only broadcast to non-Apple devices while the app is on screen. It stops by itself once the Karoo has the destination.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("One thing to know")
                }
            }
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDone)
                }
            }
        }
    }

    @ViewBuilder
    private func step(
        number: Int,
        title: String,
        detail: String,
        label: String,
        url: URL,
    ) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(number)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.accentColor, in: Circle())
                    Text(title).font(.headline)
                }
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if Links.isPlaceholder(url) {
                    // Fails loudly rather than opening a dead page.
                    Label("Link not configured yet", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                } else {
                    Link(destination: url) {
                        Text(label)
                    }
                    .font(.subheadline.weight(.medium))
                }
            }
            .padding(.vertical, 4)
        }
    }
}
