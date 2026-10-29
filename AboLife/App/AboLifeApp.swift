import AppKit
import SwiftUI

@main
struct AboLifeApp: App {
    @NSApplicationDelegateAdaptor(AboLifeAppDelegate.self) private var appDelegate
    @StateObject private var navigationCoordinator = AppNavigationCoordinator()

    @StateObject private var sync: SharedSyncCoordinator

    private let appDatabase: AppDatabase?

    init() {
        do {
            let db = try AppDatabase.makeForApplication()
            appDatabase = db
            _sync = StateObject(wrappedValue: SharedSyncCoordinator(database: db))
        } catch {
            appDatabase = nil
            _sync = StateObject(wrappedValue: SharedSyncCoordinator(database: nil))
            assertionFailure("AboLife database could not be initialized: \(error)")
        }
    }

    var body: some Scene {
        Window("AboLife", id: AppNavigationCoordinator.mainWindowID) {
            AppRouter()
                .environment(\.appDatabase, appDatabase)
                .environmentObject(navigationCoordinator)
                .environmentObject(sync)
                .task {
                    while !Task.isCancelled {
                        if sync.autoSync && !sync.hasConflict && !sync.serverAddress.isEmpty { await sync.synchronize() }
                        try? await Task.sleep(for: .seconds(30))
                    }
                }
        }
        .windowStyle(.titleBar)

        Settings {
            SettingsView(database: appDatabase)
                .environmentObject(sync)
                .frame(minWidth: 580, minHeight: 520)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 700, height: 720)
        .windowResizability(.contentMinSize)

        MenuBarExtra("AboLife", systemImage: "a.circle") {
            MenuBarQuickPanelView(database: appDatabase)
                .environmentObject(navigationCoordinator)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AboLifeAppDelegate: NSObject, NSApplicationDelegate {

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
    }
}
