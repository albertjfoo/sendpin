//
//  Brand.swift
//  sendpin
//
//  The palette from the logo, in one place.
//

import SwiftUI

enum Brand {
    /// The logo's yellow. Bright enough to carry a surface, nowhere near enough
    /// contrast to carry text — so it is only ever a background, with `ink` on
    /// top of it.
    static let yellow = Color(red: 1.0, green: 0.910, blue: 0.0)      // #FFE800

    /// The logo's near-black.
    static let ink = Color(red: 0.067, green: 0.067, blue: 0.067)     // #111111
}

/// The app mark, rounded the way iOS rounds an app icon.
struct AppMark: View {
    var size: CGFloat = 44

    var body: some View {
        Image("AppMark")
            .resizable()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.225, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// A numbered step marker in the logo's colours.
struct StepBadge: View {
    var number: Int

    var body: some View {
        Text("\(number)")
            .font(.footnote.weight(.bold))
            .foregroundStyle(Brand.ink)
            .frame(width: 24, height: 24)
            .background(Brand.yellow, in: Circle())
            .accessibilityHidden(true)
    }
}

/// The prominent row used for the two main destinations on the home screen.
///
/// Shared so Set up and How to use are visibly the same kind of thing — one
/// leads to a checklist, the other to instructions, and neither should look
/// more important than the other by accident.
struct NavCard: View {
    var icon: String
    var title: String
    var subtitle: String
    var done: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Brand.ink)
                .frame(width: 40, height: 40)
                .background(Brand.yellow, in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title).font(.headline)
                    if done {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(.green)
                            .accessibilityLabel("Complete")
                    }
                }
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // maxWidth rather than a trailing Spacer: a Spacer competes with the
            // text for width and makes the subtitle wrap far earlier than it
            // needs to. The completion tick sits beside the title for the same
            // reason — trailing, it stole a chunk of the subtitle's line.
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Both cards the same height whatever their subtitle does.
        .frame(minHeight: 44)
        .padding(.vertical, 6)
    }
}
