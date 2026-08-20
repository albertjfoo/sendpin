//
//  ShareViewController.swift
//  SendPinShare
//
//  The share sheet entry. Replaces the Shortcut: installing the app is now
//  enough to get "SendPin" into Apple Maps' share sheet, with no iCloud link
//  to tap and no regex for the user to assemble by hand.
//
//  This advertises Bluetooth itself rather than handing off to the containing
//  app. The first attempt did hand off, via extensionContext.open(), and iOS 26
//  refused it — Apple's documentation says only Today extensions may call that,
//  and on this OS it means it. Doing the work here turns out to be the better
//  design anyway: you never leave Maps.
//
//  The peripheral lives in Shared/, compiled into both targets, so there is one
//  copy of the Bluetooth contract rather than two that can drift apart.
//

import MapKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

    private let model = SendModel()

    override func viewDidLoad() {
        super.viewDidLoad()

        let sheet = UIHostingController(rootView: SendSheet(model: model))
        sheet.view.backgroundColor = .clear
        addChild(sheet)
        sheet.view.frame = view.bounds
        sheet.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(sheet.view)
        sheet.didMove(toParent: self)

        model.onClose = { [weak self] in
            self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        }

        Task { await start() }
    }

    private func start() async {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let providers = item.attachments
        else { return model.fail("Nothing was shared.") }

        // Order matters. An MKMapItem carries the coordinate as data, so it
        // needs no parsing and cannot be misread — that is what Maps actually
        // hands over. The URL and text paths are fallbacks for shares that
        // arrive from elsewhere: a link pasted into Messages, or a browser.
        for provider in providers {
            if let mapItem = await loadMapItem(from: provider) {
                let coordinate = mapItem.placemark.coordinate
                let name = mapItem.name ?? "Dropped pin"
                let glyph = PlaceSymbol.name(for: mapItem.pointOfInterestCategory)
                // Recorded before sending, so history survives even if the
                // Karoo never picks it up — a place you tried to send is still
                // a place you looked for.
                SendStore.shared.record(name: name,
                                        subtitle: mapItem.placemark.title,
                                        lat: coordinate.latitude,
                                        lng: coordinate.longitude,
                                        symbol: glyph)
                model.send(Waypoint(lat: coordinate.latitude, lng: coordinate.longitude, name: name),
                           glyph: glyph,
                           address: mapItem.placemark.title)
                return
            }
            if let url = await load(UTType.url, from: provider) as? URL,
               let destination = Destination(mapsURL: url) {
                record(destination)
                model.send(destination.waypoint)
                return
            }
            if let text = await load(UTType.plainText, from: provider) as? String,
               let url = firstURL(in: text),
               let destination = Destination(mapsURL: url) {
                record(destination)
                model.send(destination.waypoint)
                return
            }
        }

        model.fail("Couldn't find a location in that. Try sharing a place from Apple Maps.")
    }

    private func record(_ destination: Destination) {
        let w = destination.waypoint
        SendStore.shared.record(name: w.name, subtitle: nil, lat: w.lat, lng: w.lng)
    }

    private func loadMapItem(from provider: NSItemProvider) async -> MKMapItem? {
        guard provider.canLoadObject(ofClass: MKMapItem.self) else { return nil }
        return await withCheckedContinuation { continuation in
            _ = provider.loadObject(ofClass: MKMapItem.self) { object, _ in
                continuation.resume(returning: object as? MKMapItem)
            }
        }
    }

    private func load(_ type: UTType, from provider: NSItemProvider) async -> Any? {
        guard provider.hasItemConformingToTypeIdentifier(type.identifier) else { return nil }
        return try? await provider.loadItem(forTypeIdentifier: type.identifier)
    }

    private func firstURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        return detector?.firstMatch(in: text, range: range)?.url
    }
}

// MARK: - Model

/// Owns the peripheral for the life of the sheet.
///
/// A share extension is torn down the moment its request completes, which takes
/// the radio with it. So the sheet deliberately stays up until the Karoo has
/// read the waypoint — that wait *is* the feature, not a delay to hide.
@MainActor
@Observable
final class SendModel {

    enum Phase: Equatable {
        case working
        case sent
        case nothingHeard
        case failed(String)
    }

    private(set) var phase: Phase = .working
    private(set) var destination: Waypoint?
    /// What the card shows above and below the name. Held here rather than
    /// re-derived, because the MKMapItem is gone by the time the card draws.
    private(set) var glyph = PlaceSymbol.fallback
    private(set) var address: String?

    var onClose: (() -> Void)?

    private let peripheral = SendPinPeripheral()
    private var watchdog: Task<Void, Never>?

    func send(_ waypoint: Waypoint, glyph: String? = nil, address: String? = nil) {
        destination = waypoint
        self.glyph = glyph ?? PlaceSymbol.fallback
        self.address = address
        peripheral.send(waypoint)
        watchdog = Task { await watch() }
    }

    func fail(_ message: String) {
        phase = .failed(message)
    }

    /// Poll rather than observe: the peripheral predates this sheet and reports
    /// progress as plain counters. A tenth of a second is well inside the two
    /// seconds a read takes, and costs nothing over a wait this short.
    private func watch() async {
        let deadline = Date().addingTimeInterval(25)
        while !Task.isCancelled, Date() < deadline {
            if peripheral.readCount > 0 {
                withAnimation { phase = .sent }
                // Let the confirmation land before the sheet vanishes. The
                // peripheral stops advertising ~1.5s after the last read, so
                // closing here does not cut a transfer short.
                try? await Task.sleep(for: .seconds(2.2))
                close()
                return
            }
            if case .unauthorized = peripheral.managerState {
                phase = .failed("Bluetooth permission is off for SendPin.")
                return
            }
            if case .poweredOff = peripheral.managerState {
                phase = .failed("Bluetooth is off.")
                return
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        if phase == .working { phase = .nothingHeard }
    }

    func close() {
        watchdog?.cancel()
        peripheral.stop()
        onClose?()
    }
}

// MARK: - Sheet

private struct SendSheet: View {

    @Bindable var model: SendModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            SendCard(glyph: model.glyph,
                     name: model.destination?.name ?? "SendPin",
                     address: model.address,
                     phase: model.phase.card,
                     onClose: model.close)
                .frame(maxWidth: 420)
                .background(Color(.systemBackground), in: .rect(cornerRadius: 20))
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.25))
        .ignoresSafeArea()
    }
}

private extension SendModel.Phase {
    var card: SendCard.Phase {
        switch self {
        case .working:      .sending
        case .sent:         .sent
        case .nothingHeard: .nothingHeard
        case .failed(let m): .failed(m)
        }
    }
}
