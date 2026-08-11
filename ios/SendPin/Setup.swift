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

/// Whether the landing screen has been dismissed. Deliberately *not* a record
/// of whether setup was completed — the app cannot verify that the Shortcut was
/// added or the Karoo extension installed, and pretending otherwise would mean
/// nagging people who are already done.
enum SetupState {
    private static let key = "hasSeenWelcome"

    static var hasSeenWelcome: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
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

                    Text("Send a destination from your iPhone to a Karoo 2, and let the bike computer do the navigating.")
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
                    detail: "Find a place in Apple Maps and share it to SendPin.",
                )
                point(
                    icon: "dot.radiowaves.left.and.right",
                    title: "It goes over Bluetooth",
                    detail: "Much the way your power meter talks to your head unit. No cloud, no account, no internet on the Karoo.",
                )
                point(
                    icon: "location.north.circle",
                    title: "The Karoo navigates",
                    detail: "It opens its own Map Pin screen, ready to go.",
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
