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
                .fullScreenCover(isPresented: .init(
                    get: { !hasSeenWelcome }, set: { if !$0 { hasSeenWelcome = true } })) {
                    FirstRunView { hasSeenWelcome = true }
                }
        }
    }
}
