//
//  KarooSendApp.swift
//  karoo2-send
//

import SwiftUI

@main
struct KarooSendApp: App {

    @State private var peripheral = KarooSendPeripheral()

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
                    peripheral.mode = .waypoint
                    peripheral.send(waypoint)
                }
        }
    }
}
