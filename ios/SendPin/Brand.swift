//
//  Brand.swift
//  SendPin
//
//  App-only chrome. The palette and the mark itself live in Shared/AppMark.swift
//  so the share extension can draw the same card.
//

import SwiftUI

/// The paper plane cut out of the app icon.
///
/// The same mark the website's "Send Your First Pin" button uses, so the
/// gesture looks identical wherever it appears. A template image, so it takes
/// whatever colour it is placed on.
struct SendGlyph: View {
    var size: CGFloat = 15

    /// The plane fills its canvas corner to corner, so its bounding box is
    /// perfectly centred while its mass is not: measured, the ink's centre of
    /// gravity sits 6.3% right and 6.7% above centre, because the body is up in
    /// one corner and only the thin tail reaches the other. Centring the box
    /// therefore looks high and right. These two numbers put the mass in the
    /// middle, which is what the eye reads as centred.
    private static let opticalX: CGFloat = -0.063
    private static let opticalY: CGFloat = 0.067

    var body: some View {
        Image("SendGlyph")
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .offset(x: size * Self.opticalX, y: size * Self.opticalY)
            .accessibilityHidden(true)
    }
}

/// The non-primary buttons in the sheets.
///
/// systemGray6 on a white sheet was very nearly invisible — the buttons read as
/// labels. A stronger fill plus a hairline edge makes them obviously tappable
/// without competing with the black Send button above them.
private struct SheetSecondary: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(Color(.systemGray3), lineWidth: 0.5)
            )
    }
}

extension View {
    func sheetSecondary() -> some View { modifier(SheetSecondary()) }
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
/// A card's glyph: either an SF Symbol or one of our own drawings.
enum NavIcon {
    case symbol(String)
    case asset(String)

    @ViewBuilder
    var view: some View {
        switch self {
        case .symbol(let name):
            Image(systemName: name).font(.title3)
        case .asset(let name):
            // Template rendering so it takes the ink colour like a symbol does,
            // and a fixed frame so custom art matches SF Symbol optical size
            // rather than filling the tile.
            Image(name)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 21, height: 21)
        }
    }
}

struct NavCard: View {
    var icon: NavIcon
    var title: String
    var subtitle: String
    var done: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            icon.view
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

// MARK: - Sheet sizing

private struct SheetHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Sizes a sheet to its content instead of a number picked by hand.
///
/// Every fixed detent here was wrong for some place: a one-line address left a
/// gap, a two-line one left less, and the gap under the last button was really
/// the home indicator being counted twice. Measuring removes the guess.
private struct FitToContent: ViewModifier {
    /// Only used for the first frame, before the measurement arrives.
    var estimate: CGFloat
    @State private var height: CGFloat?

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: SheetHeightKey.self, value: proxy.size.height)
                }
            )
            .onPreferenceChange(SheetHeightKey.self) { measured in
                // The content is laid out above the home indicator, so the
                // detent has to add that back or the sheet clips its own
                // bottom button.
                if measured > 0 { height = measured + Self.bottomInset }
            }
            .presentationDetents([.height(height ?? estimate)])
            .presentationDragIndicator(.visible)
    }

    private static var bottomInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow?.safeAreaInsets.bottom }
            .first ?? 0
    }
}

extension View {
    /// `estimate` only has to be close — it is replaced on the first layout.
    func fitSheetToContent(estimate: CGFloat) -> some View {
        modifier(FitToContent(estimate: estimate))
    }
}

// MARK: - Karoo

/// The head unit, drawn the way the website draws it: a dark bezel, the four
/// side buttons, and a real screenshot inside. Used where the app needs to
/// point at the Karoo rather than at itself.
struct KarooFrame: View {
    var width: CGFloat = 108

    private var bezel: CGFloat { width * 0.037 }
    private var corner: CGFloat { width * 0.105 }

    var body: some View {
        Image("KarooScreen")
            .resizable()
            .aspectRatio(480.0 / 800.0, contentMode: .fit)
            .frame(width: width - bezel * 2)
            .clipShape(RoundedRectangle(cornerRadius: corner - bezel, style: .continuous))
            .padding(bezel)
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(Color(red: 0.137, green: 0.157, blue: 0.184))
            )
            .overlay(alignment: .leading) { buttons.offset(x: -bezel / 1.6) }
            .overlay(alignment: .trailing) { buttons.offset(x: bezel / 1.6) }
            .accessibilityLabel("A Karoo 2 running SendPin")
    }

    private var buttons: some View {
        VStack(spacing: width * 0.20) {
            ForEach(0..<2, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color(red: 0.137, green: 0.157, blue: 0.184))
                    .frame(width: bezel * 0.6, height: width * 0.115)
            }
        }
        .padding(.bottom, width * 0.18)
    }
}
