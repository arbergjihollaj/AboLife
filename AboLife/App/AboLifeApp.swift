import SwiftUI

@main
struct AboLifeApp: App {
    var body: some Scene {
        WindowGroup {
            AppRouter()
        }
        .windowStyle(.titleBar)
    }
}
