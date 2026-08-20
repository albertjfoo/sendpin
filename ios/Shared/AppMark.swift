//
//  AppMark.swift
//  Shared
//
//  The logo, and the two colours it is made of.
//
//  In Shared/ rather than the app because the share extension shows the same
//  card when a send comes from Apple Maps, and a card that is meant to look
//  identical cannot be built from two different sets of assets. The image lives
//  in Shared.xcassets for the same reason.
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
