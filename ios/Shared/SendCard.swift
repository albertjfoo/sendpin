//
//  SendCard.swift
//  Shared
//
//  The card shown while a place is on its way to the Karoo.
//
//  One component, both entry points. A send that starts in Apple Maps runs in
//  the share extension and a send that starts in the app runs in the app, but
//  they are the same act and used to be two hand-copied layouts that drifted
//  apart every time either was touched.
//
//  The height is fixed on purpose. The card used to grow and shrink as the
//  phase changed, which moved the button out from under a thumb mid-tap.
//

import SwiftUI

struct SendCard: View {

    enum Phase: Equatable {
        case sending
        case sent
        case nothingHeard
        case failed(String)
    }

    /// The place's own glyph — a cup for a café, a bag for a shop — matching
    /// the history list. Falls back to a pin for anything Maps did not classify.
    var glyph: String
    var name: String
    var address: String?
    var phase: Phase
    var onClose: () -> Void

    /// Enough for the tallest state, so no phase changes the card's height.
    private let statusHeight: CGFloat = 86
    private let buttonHeight: CGFloat = 48

    var body: some View {
        VStack(spacing: 0) {
            // The history row's treatment, one step darker: the row's grey sits
            // on a white cell, while this sits on a sheet that is already about
            // systemGray6, where the disc all but disappeared.
            Image(systemName: glyph)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 46, height: 46)
                .background(Color(.systemGray5), in: Circle())

            Text(name)
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
                .padding(.top, 12)

            if let address {
                Text(address)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.top, 3)
            }

            // Both states are always present and cross-faded, rather than one
            // being inserted as the other is removed.
            //
            // The insert/remove version animated on paper and not on the phone:
            // a `.transition` only plays if SwiftUI attributes the structural
            // change to an animation, and here the change arrives from a
            // background Task through two different hosts. Interpolating
            // opacity and scale on views that both already exist cannot
            // silently do nothing.
            ZStack {
                // Each part keeps the row it replaces: the tick lands on the
                // spinner's own centre, the line lands where Cancel was.
                VStack(spacing: 0) {
                    status.frame(height: statusHeight)
                    cancelButton.frame(height: buttonHeight)
                }
                .opacity(phase == .sent ? 0 : 1)
                .allowsHitTesting(phase != .sent)

                VStack(spacing: 0) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 52))
                        .foregroundStyle(.green)
                        .scaleEffect(phase == .sent ? 1 : 0.5)
                        .frame(height: statusHeight)
                    Text("Confirm the pin on your Karoo")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        // Top of its row rather than centred, which closes the
                        // gap under the tick by 14pt. The tick itself stays put
                        // — it has to keep the spinner's centre for the swap to
                        // read as a replacement.
                        .frame(height: buttonHeight, alignment: .top)
                }
                // Nudged down, so the tick reads as its own beat rather than
                // crowding the address above it.
                .offset(y: 10)
                .opacity(phase == .sent ? 1 : 0)
                .accessibilityHidden(phase != .sent)
            }
            // Constant, so nothing moves under a thumb already heading for
            // Cancel — and so the tick has the button's row to fill.
            .frame(height: statusHeight + buttonHeight)
            .frame(maxWidth: .infinity)
            .animation(.spring(response: 0.36, dampingFraction: 0.72), value: phase)
        }
        .padding(.top, 26)
        .padding(.horizontal, 20)
        .padding(.bottom, 14)
    }

    private var cancelButton: some View {
        Button(action: onClose) {
            Text(phase == .sending ? "Cancel" : "Done")
                // On the label, not the Button: styling the button itself
                // leaves the tap target the size of the word, so a tap
                // anywhere else in the pill did nothing.
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: buttonHeight)
                .background(Color(.systemGray5),
                            in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(Color(.systemGray3), lineWidth: 0.5)
                )
                .contentShape(Rectangle())
        }
    }

    @ViewBuilder
    private var status: some View {
        switch phase {
        case .sending:
            VStack(spacing: 6) {
                ProgressView()
                Text("Sending to your Karoo…").font(.subheadline).foregroundStyle(.secondary)
            }
        case .sent:
            EmptyView()   // handled above, where it can animate in place
        case .nothingHeard:
            Text("Check the SendPin extension on the Karoo to verify that it says listening.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        case .failed(let message):
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
