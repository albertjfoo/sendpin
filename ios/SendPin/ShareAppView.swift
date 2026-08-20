//
//  ShareAppView.swift
//  SendPin
//
//  Getting SendPin onto someone else's phone. A QR is the fastest path when
//  they're standing next to you; the share sheet covers everyone else.
//

import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct ShareAppView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            AppMark(size: 46)

            Text("Share SendPin").font(.title3.weight(.bold))

            if let qr = QRCode.image(for: Links.appStore.absoluteString) {
                Image(uiImage: qr)
                    .interpolation(.none)          // keep the modules crisp
                    .resizable()
                    .scaledToFit()
                    .frame(width: 176, height: 176)
            }

            orDivider
                .padding(.horizontal, 18)

            ShareLink(item: Links.appStore) {
                Label("Share a link", systemImage: "square.and.arrow.up").sheetSecondary()
            }
            .padding(.horizontal, 18)
        }
        .padding(.top, 22)
        .padding(.bottom, 12)
        .fitSheetToContent(estimate: 400)
    }
}

private extension ShareAppView {
    /// Two ways to hand this over, neither of them the fallback.
    var orDivider: some View {
        HStack(spacing: 12) {
            line
            Text("or").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            line
        }
    }

    var line: some View {
        Rectangle().fill(Color(.systemGray4)).frame(height: 0.5)
    }
}

enum QRCode {
    /// A real code, not a drawing — it encodes whatever URL it is handed, so it
    /// keeps working the day the App Store link replaces the placeholder.
    static func image(for string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?
                .transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cg = CIContext().createCGImage(output, from: output.extent)
        else { return nil }
        return UIImage(cgImage: cg)
    }
}
