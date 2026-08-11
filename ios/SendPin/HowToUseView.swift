//
//  HowToUseView.swift
//  sendpin
//
//  Its own page rather than a section, because once setup is done this is the
//  only thing left to read — and it is what someone comes back to when they
//  have forgotten which app to share to.
//

import SwiftUI

struct HowToUseView: View {
    var body: some View {
        List {
            Section {
                step(1, "Find a place in Apple Maps",
                     "Google Maps isn’t supported — its share links don’t carry coordinates.")
                step(2, "Share → Send to Karoo",
                     "If it isn’t in the share sheet, scroll to the bottom and tap Edit Actions.")
                step(3, "Keep this screen open",
                     "iPhones stop broadcasting to non-Apple devices the moment an app goes to the background.")
                step(4, "The Karoo shows the pin",
                     "It beeps and opens its own Map Pin screen, ready to navigate.")
            }

            Section("Worth knowing") {
                note("The Karoo needs a GPS fix, and the offline map region for that area. Indoors you’ll get the pin and a “GPS required”.")
                note("Sending the same place twice does nothing for two minutes. That stops a phone left broadcasting from reopening the pin screen over and over.")
                note("The phone stops broadcasting by itself once the Karoo has the destination.")
            }
        }
        .navigationTitle("How to use")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func step(_ n: Int, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            StepBadge(number: n)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 3)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 2)
    }
}
