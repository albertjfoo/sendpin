//
//  Setup.swift
//  sendpin
//
//  The first-run landing screen, and the handful of URLs the app links out to.
//

import SwiftUI

// MARK: - Links

/// Everything the app links out to, in one place.
///
/// Any URL still pointing at example.com renders as a visible warning rather
/// than a tappable link, so a missed one fails loudly instead of sending
/// someone to a dead page.
enum Links {
    /// The Shortcut, shared from the Shortcuts app via Share → Copy iCloud Link.
    /// Must be an iCloud link: a .shortcut file hosted anywhere else cannot be
    /// installed directly on iOS.
    static let shortcut = URL(string: "https://www.icloud.com/shortcuts/6aacca931a7d41d8b4f7821992f96256")!

    /// The project page carrying the Karoo APK and install instructions.
    static let karooExtension = URL(string: "https://github.com/albertjfoo/sendpin")!

    static func isPlaceholder(_ url: URL) -> Bool {
        url.host?.contains("example.com") ?? true
    }
}

// MARK: - First-run state

/// Keys backing the app's few persisted flags.
///
/// The two setup flags are user-asserted, not verified. The phone genuinely
/// cannot tell whether the Shortcut was added or the Karoo extension installed
/// — it is a BLE peripheral, it advertises and waits — so these record what the
/// user says they have done, which is the only signal available.
enum SetupKey {
    static let hasSeenWelcome = "hasSeenWelcome"
    static let shortcutAdded = "shortcutAdded"
    static let extensionInstalled = "extensionInstalled"
}

// MARK: - Landing screen

struct WelcomeView: View {
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            VStack(spacing: 24) {
                AppMark(size: 96)

                VStack(spacing: 12) {
                    Text("SendPin")
                        .font(.largeTitle.weight(.bold))

                    Text("Send a destination from your iPhone to your Karoo 2.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 32)

            VStack(alignment: .leading, spacing: 20) {
                point(
                    icon: "map",
                    title: "Share from Maps",
                    detail: "Find a place in Apple Maps and share it to your Karoo 2 in seconds.",
                )
                point(
                    icon: "dot.radiowaves.left.and.right",
                    title: "No internet required",
                    detail: "It travels over the Karoo\u{2019}s onboard Bluetooth. No cloud, no account, no SIM.",
                )
                point(
                    icon: "location.north.circle",
                    title: "Ride there",
                    detail: "Navigate to the pin with the Karoo\u{2019}s own turn-by-turn navigation.",
                )
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 32)

            Button(action: onDismiss) {
                Text("Get started")
                    .font(.headline)
                    .foregroundStyle(Brand.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Brand.yellow, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .interactiveDismissDisabled(false)
    }

    private func point(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Brand.ink)
                .frame(width: 32, height: 32)
                .background(Brand.yellow, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
