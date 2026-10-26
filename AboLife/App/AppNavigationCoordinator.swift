import AppKit
import SwiftUI

@MainActor
final class AppNavigationCoordinator: ObservableObject {
    static let mainWindowID = "main"

    @Published var selectedSection: AppSection? = .calendar
    private var isOpeningMainWindow = false

    func select(_ section: AppSection) {
        selectedSection = section
    }

    func shouldOpenMainWindow() -> Bool {
        if focusExistingMainWindow() {
            return false
        }
        guard !isOpeningMainWindow else {
            return false
        }
        isOpeningMainWindow = true
        return true
    }

    func finishOpeningMainWindow() {
        isOpeningMainWindow = false
        _ = focusExistingMainWindow()
    }

    @discardableResult
    func focusExistingMainWindow() -> Bool {
        NSApp.activate(ignoringOtherApps: true)

        let windows = mainWindows()
        guard let mainWindow = windows.first else {
            return false
        }

        for duplicate in windows.dropFirst() {
            duplicate.close()
        }

        mainWindow.makeKeyAndOrderFront(nil)
        return true
    }

    private func mainWindows() -> [NSWindow] {
        NSApp.windows.filter { window in
            guard window.level == .normal else { return false }
            guard window.canBecomeKey || window.canBecomeMain else { return false }

            if window.identifier?.rawValue == Self.mainWindowID {
                return true
            }
            return window.title == "AboLife Kalender"
        }
    }
}
