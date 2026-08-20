//
//  FirstRunView.swift
//  SendPin
//
//  Two screens: what this is, then the one question that decides where to send
//  them. The phone can't verify the answer — the devices never pair — so this
//  records what they say, and a send that is never picked up is the real check.
//

import SwiftUI

struct FirstRunView: View {
    var onDone: () -> Void
    @AppStorage(SetupKey.extensionInstalled) private var extensionInstalled = false
    @Environment(\.openURL) private var openURL
    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            if page == 0 {
                WelcomeView { page = 1 }
            } else {
                question
            }
        }
        // A full-screen cover does not supply a background of its own, so
        // without this the home screen shows straight through the welcome.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private var question: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 40)
            // The Karoo, not the app: this screen is asking about the head
            // unit, and it is the same picture the website shows at step 2.
            KarooFrame(width: 112)
            Text("One last thing")
                .font(.title2.weight(.bold))
                .padding(.top, 20)
            Text("Your Karoo needs a small extension to receive pins. Have you installed it yet?")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 8)
                .padding(.horizontal, 32)

            VStack(spacing: 10) {
                choice(title: "Yes, it's on my Karoo", detail: "Take me to the app") {
                    extensionInstalled = true
                    onDone()
                }
                choice(title: "Not yet — show me how",
                       detail: "Opens the guide, so you can pick it up on a computer") {
                    openURL(Links.site)
                    onDone()
                }
            }
            .padding(.top, 26)
            .padding(.horizontal, 24)

            Spacer()
        }
    }

    private func choice(title: String, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(15)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
