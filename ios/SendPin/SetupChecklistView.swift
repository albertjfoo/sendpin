//
//  SetupChecklistView.swift
//  sendpin
//
//  The two things that have to happen before anything works, on their own page.
//

import SwiftUI

struct SetupChecklistView: View {

    @Environment(\.openURL) private var openURL

    @AppStorage(SetupKey.shortcutAdded) private var shortcutAdded = false
    @AppStorage(SetupKey.extensionInstalled) private var extensionInstalled = false

    private var complete: Bool { shortcutAdded && extensionInstalled }

    var body: some View {
        List {
            Section {
                row(
                    title: "Add the Shortcut",
                    detail: "Puts “Send to Karoo” in the Maps share sheet.",
                    url: Links.shortcut,
                    done: $shortcutAdded,
                )
                row(
                    title: "Install the Karoo extension",
                    detail: "The Karoo needs a small app to receive destinations.",
                    url: Links.karooExtension,
                    done: $extensionInstalled,
                )
            }

            if complete {
                // The same card as the home screen, deliberately. Once setup is
                // done the next thing to do is already a familiar object, so it
                // reads as "go here" rather than as a new control to decipher.
                Section("Next") {
                    NavigationLink {
                        HowToUseView()
                    } label: {
                        NavCard(
                            icon: "paperplane.fill",
                            title: "How to use",
                            subtitle: "Share a place from Maps and send it",
                        )
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.default, value: complete)
        .navigationTitle("Set up")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Tapping the row opens the link; the circle marks it done.
    ///
    /// The tick is user-asserted, not verified. The phone cannot tell whether a
    /// Shortcut was added or an extension installed — it is a BLE peripheral,
    /// it advertises and waits — so this records what you say you have done.
    @ViewBuilder
    private func row(title: String, detail: String, url: URL, done: Binding<Bool>) -> some View {
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
                // A Link tints its whole subtree with the accent colour, which
                // overrode the explicit .secondary on the detail line and made
                // both lines blue. A plain-styled Button lets the two be
                // coloured independently: title reads as the tappable thing,
                // detail stays supporting text.
                Button {
                    openURL(url)
                } label: {
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title)
                                .font(.body)
                                .foregroundStyle(Color.accentColor)
                            Text(detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "arrow.up.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 3)
    }
}
