//
//  SendingSheet.swift
//  SendPin
//
//  Resending something already in the history. The card itself is SendCard,
//  shared with the share extension, so a send looks the same whichever end it
//  starts from. iOS hides the service UUID from non-Apple devices the moment
//  the app backgrounds, which is why this waits rather than dismissing.
//

import SwiftUI

struct SendingSheet: View {
    var place: Place
    var peripheral: SendPinPeripheral
    @Environment(\.dismiss) private var dismiss

    @State private var phase: SendCard.Phase = .sending
    /// Reads already on the clock before this send. The counter never resets,
    /// so without a baseline a resend sees the last send's read and finishes
    /// before it has begun.
    @State private var baseline = 0

    var body: some View {
        SendCard(glyph: place.glyph,
                 name: place.name,
                 address: place.subtitle,
                 phase: phase,
                 onClose: finish)
            .fitSheetToContent(estimate: 330)
            .task { await run() }
    }

    private func run() async {
        baseline = peripheral.readCount
        peripheral.send(place.waypoint)
        let deadline = Date().addingTimeInterval(25)
        while Date() < deadline {
            if peripheral.readCount > baseline {
                withAnimation { phase = .sent }
                // Long enough to read the confirmation and the line under it.
                try? await Task.sleep(for: .seconds(2.2))
                finish()
                return
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        phase = .nothingHeard
    }

    private func finish() {
        peripheral.stop()
        dismiss()
    }
}
