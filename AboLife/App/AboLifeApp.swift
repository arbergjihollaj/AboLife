import SwiftUI

@main
struct AboLifeApp: App {
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
        WindowGroup {
            AppRouter()
                .environment(\.appDatabase, appDatabase)
        }
        .windowStyle(.titleBar)
    }
}
