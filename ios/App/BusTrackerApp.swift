import SwiftUI
import SwiftData

@main
struct BusTrackerApp: App {
    @StateObject private var appState = AppState()
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: Trip.self)
        } catch {
            fatalError("SwiftData 初始化失败: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .modelContainer(modelContainer)
                .preferredColorScheme(colorScheme(for: appState.preferredColorSchemeRaw))
                .tint(Color(hex: appState.accentColorHex))
                .onAppear {
                    appState.modelContext = modelContainer.mainContext
                    appState.notificationManager.requestAuthorization()
                }
        }
    }

    private func colorScheme(for raw: String) -> ColorScheme? {
        switch raw {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}
