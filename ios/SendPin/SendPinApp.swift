//
//  SendPinApp.swift
//  sendpin
//

import SwiftUI

@main
struct SendPinApp: App {

    @State private var peripheral = SendPinPeripheral()
    @AppStorage(SetupKey.hasSeenWelcome) private var hasSeenWelcome = false

    var body: some Scene {
        WindowGroup {
            ContentView(peripheral: peripheral)
                // R3: iOS only advertises service UUIDs where a non-Apple
                // central can see them while the app is foregrounded, so the
                // screen must stay awake for the few seconds a send takes.
                .persistentSystemOverlays(.hidden)
                .onAppear {
                    UIApplication.shared.isIdleTimerDisabled = true
                    peripheral.activate()
                }
                .onDisappear {
                    UIApplication.shared.isIdleTimerDisabled = false
                }
                .onOpenURL { url in
                    guard let waypoint = Waypoint(url: url) else {
                        peripheral.reportBadURL(url)
                        return
                    }
                    // Still honoured for anyone on the old Shortcut.
                    SendStore.shared.record(name: waypoint.name, subtitle: nil,
                                            lat: waypoint.lat, lng: waypoint.lng)
                    peripheral.send(waypoint)
                }
                .fullScreenCover(isPresented: .init(
                    get: { !hasSeenWelcome }, set: { if !$0 { hasSeenWelcome = true } })) {
                    FirstRunView { hasSeenWelcome = true }
                }
        }
    }
}
