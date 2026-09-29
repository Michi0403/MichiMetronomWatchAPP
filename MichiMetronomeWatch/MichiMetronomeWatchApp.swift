import SwiftUI

@main
struct MichiMetronomeWatchApp: App {
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
        }
    }
}
