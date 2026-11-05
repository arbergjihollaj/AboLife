import OSLog
import SwiftUI

@MainActor
final class AppSession: ObservableObject {
    @Published private(set) var database: AppDatabase?
    @Published private(set) var failedToOpenDatabase = false
    @Published private(set) var ai: AIAssistantStore
    @Published private(set) var sync: SharedSyncCoordinator
    let design: AboLifeDesignStore
    let preferences: UserDefaults
    private let usesIsolatedData: Bool

    private let logger = Logger(subsystem: "com.private.AboLife", category: "Persistence")
    private let makeDatabase: () throws -> AppDatabase

    init(makeDatabase: @escaping () throws -> AppDatabase = { try AppDatabase.makeForApplication() }) {
        self.makeDatabase = makeDatabase
        usesIsolatedData = DemoData.isEnabled || NSClassFromString("XCTestCase") != nil
        preferences = usesIsolatedData ? UserDefaults(suiteName: "com.private.AboLife.isolated.\(UUID())")! : .standard
        design = AboLifeDesignStore(defaults: preferences)
        ai = AIAssistantStore.previewStore()
        sync = SharedSyncCoordinator(database: nil, defaults: preferences)
        openDatabase()
    }

    func openDatabase() {
        do {
            let database = try makeDatabase()
            self.database = database
            ai = AIAssistantStore(
                database: database,
                historyURL: usesIsolatedData
                    ? FileManager.default.temporaryDirectory.appendingPathComponent(
                        "AboLife-AI-tests-\(UUID())/Conversations.json") : nil,
                loadCredentials: !usesIsolatedData)
            sync = SharedSyncCoordinator(database: database, defaults: preferences)
            failedToOpenDatabase = false
        } catch {
            logger.error("Could not open local database: \(String(describing: error), privacy: .private)")
            database = nil
            failedToOpenDatabase = true
        }
    }
}

struct DatabaseRecoveryView: View {
    @ObservedObject var session: AppSession

    var body: some View {
        VStack(alignment: .leading, spacing: AboLifeSpacing.section) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(AboLifeColors.habits)
                .accessibilityHidden(true)
            Text("Lokale Daten nicht verfügbar")
                .font(AboLifeTypography.sectionTitle)
            Text(
                "AboLife konnte die Datenbank nicht öffnen. Prüfe freien Speicher und Zugriffsrechte. Du kannst das Öffnen erneut versuchen; es wird keine leere Datenbank als Ersatz angelegt."
            )
            .font(AboLifeTypography.body)
            .foregroundStyle(AboLifeColors.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            Button("Erneut versuchen", systemImage: "arrow.clockwise", action: session.openDatabase)
                .buttonStyle(.borderedProminent)
                .tint(AboLifeColors.action)
        }
        .padding(AboLifeSpacing.generous)
        .frame(maxWidth: 560, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AboLifeColors.pageBackground)
    }
}
