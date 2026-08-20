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
    /// The installer and the whole written guide. The app deliberately does not
    /// repeat any of it — the site explains it better and stays current.
    static let site = URL(string: "https://github.com/albertjfoo/sendpin#installing")!

    /// The project page carrying the Karoo APK and install instructions.
    static let karooExtension = URL(string: "https://github.com/albertjfoo/sendpin")!

    static let feedback = URL(string: "https://forms.gle/1TU9ZwDXzMth9HCL8")!

    /// Placeholder until the app is live; the share sheet falls back to the site.
    static let appStore = URL(string: "https://github.com/albertjfoo/sendpin")!

    static func isPlaceholder(_ url: URL) -> Bool {
        url.host?.contains("example.com") ?? true
    }
}

// MARK: - First-run state

/// Keys backing the app's few persisted flags.
///
/// The setup flag is user-asserted, not verified. The phone genuinely cannot
/// tell whether the Karoo extension is installed — it is a BLE peripheral, it
/// advertises and waits — so this records what the user says they have done,
/// which is the only signal available.
enum SetupKey {
    static let hasSeenWelcome = "hasSeenWelcome.v2"
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
                    detail: "Find a place in Apple Maps, tap Share, select SendPin and navigate on your Karoo.",
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
                Text("Continue")
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
