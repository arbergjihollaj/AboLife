import AppKit
import SwiftUI

@main
struct AboLifeApp: App {
    @NSApplicationDelegateAdaptor(AboLifeAppDelegate.self) private var appDelegate
    @StateObject private var navigationCoordinator = AppNavigationCoordinator()

    @StateObject private var session = AppSession()

    var body: some Scene {
        Window("AboLife", id: AppNavigationCoordinator.mainWindowID) {
            Group {
                if session.failedToOpenDatabase {
                    DatabaseRecoveryView(session: session)
                } else {
                    AppRouter(database: session.database)
                }
            }
            .environment(\.appDatabase, session.database)
            .environmentObject(navigationCoordinator)
            .environmentObject(session.sync)
            .environmentObject(session.ai)
            .aboLifeDesign(session.design)
            .aboLifeAppearance()
            .defaultAppStorage(session.preferences)
            .task {
                while !Task.isCancelled {
                    if session.sync.autoSync && !session.sync.hasConflict && !session.sync.serverAddress.isEmpty {
                        await session.sync.synchronize()
                    }
                    try? await Task.sleep(for: .seconds(30))
                }
            }
        }
        .windowStyle(.titleBar)

        Settings {
            Group {
                if session.failedToOpenDatabase {
                    DatabaseRecoveryView(session: session)
                } else {
                    SettingsView(database: session.database)
                }
            }
            .environmentObject(session.sync)
            .environmentObject(session.ai)
            .frame(minWidth: 580, minHeight: 520)
            .aboLifeDesign(session.design)
            .aboLifeAppearance()
            .defaultAppStorage(session.preferences)
        }
        .defaultSize(width: 700, height: 720)
        .windowResizability(.contentMinSize)

        MenuBarExtra {
            Group {
                if session.failedToOpenDatabase {
                    DatabaseRecoveryView(session: session).frame(width: 320)
                } else {
                    MenuBarQuickPanelView(database: session.database)
                }
            }
            .environmentObject(navigationCoordinator)
            .aboLifeDesign(session.design)
            .aboLifeAppearance()
            .defaultAppStorage(session.preferences)
        } label: {
            Text("a.")
                .font(.system(size: 17, weight: .semibold))
                .accessibilityLabel("AboLife")
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
