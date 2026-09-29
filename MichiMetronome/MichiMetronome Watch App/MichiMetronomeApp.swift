<<<<<<< HEAD
import SwiftUI

@main
struct MichiMetronomeApp: App {
    @StateObject private var engine = MetronomeEngine()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(engine)
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        engine.becameActive()
                    case .background:
                        engine.enteredBackground()
                    case .inactive:
                        break
                    @unknown default:
                        break
                    }
                }
=======
//
//  MichiMetronomeApp.swift
//  MichiMetronome Watch App
//
//  Created by Michael Fleischer on 29.09.26.
//

import SwiftUI

@main
struct MichiMetronome_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
>>>>>>> 6243a46ca19444a29510c1d624538731ff550dbb
        }
    }
}
