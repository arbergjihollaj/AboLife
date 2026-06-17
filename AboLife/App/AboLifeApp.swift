import AppKit
import SwiftUI

@main
struct AboLifeApp: App {
    @NSApplicationDelegateAdaptor(AboLifeAppDelegate.self) private var appDelegate
    @StateObject private var telegramCoordinator = TelegramAppCoordinator()
    @StateObject private var navigationCoordinator = AppNavigationCoordinator()

    private let appDatabase: AppDatabase?

    init() {
        do {
            appDatabase = try AppDatabase.makeDefault()
        } catch {
            appDatabase = nil
            assertionFailure("AboLife database could not be initialized: \(error)")
        }
    }

    var body: some Scene {
        Window("AboLife", id: AppNavigationCoordinator.mainWindowID) {
            AppRouter()
                .environment(\.appDatabase, appDatabase)
                .environmentObject(telegramCoordinator)
                .environmentObject(navigationCoordinator)
                .onAppear {
                    appDelegate.telegramCoordinator = telegramCoordinator
                    telegramCoordinator.configure(database: appDatabase)
                    telegramCoordinator.applyAutoStartIfNeeded()
                }
        }
        .windowStyle(.titleBar)

        MenuBarExtra("AboLife", systemImage: "sparkles") {
            MenuBarQuickPanelView(database: appDatabase)
                .environmentObject(telegramCoordinator)
                .environmentObject(navigationCoordinator)
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AboLifeAppDelegate: NSObject, NSApplicationDelegate {
    weak var telegramCoordinator: TelegramAppCoordinator?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        telegramCoordinator?.stopForAppQuit()
    }
}
