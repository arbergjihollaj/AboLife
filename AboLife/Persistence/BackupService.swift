import Foundation
import GRDB

struct AboLifeExportPayload: Codable, Equatable {
    let exportVersion: Int
    let createdAt: Date
    let appName: String
    let nutritionEntries: [NutritionEntryRecord]
    let nutritionTemplates: [NutritionTemplateRecord]
    let workoutSessions: [WorkoutSessionRecord]
    let workoutExercises: [WorkoutExerciseRecord]
    let workoutSets: [WorkoutSetRecord]
    let financeEntries: [FinanceEntryRecord]
    let financeCategoryBudgets: [FinanceCategoryBudgetRecord]
    let financeFixedCosts: [FinanceFixedCostRecord]
    let financeSavingsGoals: [FinanceSavingsGoalRecord]
    let financeAnalysis: FinanceExportAnalysis?
    let habitEntries: [HabitEntryRecord]
    let weightEntries: [WeightEntryRecord]
    let bodyMetricEntries: [BodyMetricEntryRecord]
    let weeklyReviews: [WeeklyReviewRecord]
    let settings: [AppSettingsRecord]

    enum CodingKeys: String, CodingKey {
        case exportVersion
        case createdAt
        case appName
        case nutritionEntries
        case nutritionTemplates
        case workoutSessions
        case workoutExercises
        case workoutSets
        case financeEntries
        case financeCategoryBudgets
        case financeFixedCosts
        case financeSavingsGoals
        case financeAnalysis
        case habitEntries
        case weightEntries
        case bodyMetricEntries
        case weeklyReviews
        case settings
    }

    init(
        exportVersion: Int,
        createdAt: Date,
        appName: String,
        nutritionEntries: [NutritionEntryRecord],
        nutritionTemplates: [NutritionTemplateRecord],
        workoutSessions: [WorkoutSessionRecord],
        workoutExercises: [WorkoutExerciseRecord] = [],
        workoutSets: [WorkoutSetRecord] = [],
        financeEntries: [FinanceEntryRecord],
        financeCategoryBudgets: [FinanceCategoryBudgetRecord],
        financeFixedCosts: [FinanceFixedCostRecord],
        financeSavingsGoals: [FinanceSavingsGoalRecord],
        financeAnalysis: FinanceExportAnalysis?,
        habitEntries: [HabitEntryRecord],
        weightEntries: [WeightEntryRecord],
        bodyMetricEntries: [BodyMetricEntryRecord],
        weeklyReviews: [WeeklyReviewRecord],
        settings: [AppSettingsRecord]
    ) {
        self.exportVersion = exportVersion
        self.createdAt = createdAt
        self.appName = appName
        self.nutritionEntries = nutritionEntries
        self.nutritionTemplates = nutritionTemplates
        self.workoutSessions = workoutSessions
        self.workoutExercises = workoutExercises
        self.workoutSets = workoutSets
        self.financeEntries = financeEntries
        self.financeCategoryBudgets = financeCategoryBudgets
        self.financeFixedCosts = financeFixedCosts
        self.financeSavingsGoals = financeSavingsGoals
        self.financeAnalysis = financeAnalysis
        self.habitEntries = habitEntries
        self.weightEntries = weightEntries
        self.bodyMetricEntries = bodyMetricEntries
        self.weeklyReviews = weeklyReviews
        self.settings = settings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.exportVersion = try container.decode(Int.self, forKey: .exportVersion)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.appName = try container.decode(String.self, forKey: .appName)
        self.nutritionEntries = try container.decode([NutritionEntryRecord].self, forKey: .nutritionEntries)
        self.nutritionTemplates = try container.decodeIfPresent([NutritionTemplateRecord].self, forKey: .nutritionTemplates) ?? []
        self.workoutSessions = try container.decode([WorkoutSessionRecord].self, forKey: .workoutSessions)
        self.workoutExercises = try container.decodeIfPresent([WorkoutExerciseRecord].self, forKey: .workoutExercises) ?? []
        self.workoutSets = try container.decodeIfPresent([WorkoutSetRecord].self, forKey: .workoutSets) ?? []
        self.financeEntries = try container.decode([FinanceEntryRecord].self, forKey: .financeEntries)
        self.financeCategoryBudgets = try container.decodeIfPresent([FinanceCategoryBudgetRecord].self, forKey: .financeCategoryBudgets) ?? []
        self.financeFixedCosts = try container.decodeIfPresent([FinanceFixedCostRecord].self, forKey: .financeFixedCosts) ?? []
        self.financeSavingsGoals = try container.decodeIfPresent([FinanceSavingsGoalRecord].self, forKey: .financeSavingsGoals) ?? []
        self.financeAnalysis = try container.decodeIfPresent(FinanceExportAnalysis.self, forKey: .financeAnalysis)
        self.habitEntries = try container.decode([HabitEntryRecord].self, forKey: .habitEntries)
        self.weightEntries = try container.decodeIfPresent([WeightEntryRecord].self, forKey: .weightEntries) ?? []
        self.bodyMetricEntries = try container.decode([BodyMetricEntryRecord].self, forKey: .bodyMetricEntries)
        self.weeklyReviews = try container.decode([WeeklyReviewRecord].self, forKey: .weeklyReviews)
        self.settings = try container.decode([AppSettingsRecord].self, forKey: .settings)
    }
}

struct FinanceExportAnalysis: Codable, Equatable {
    let generatedForMonth: String
    let currency: String
    let monthlySpent: Double
    let monthlyIncome: Double
    let monthlyBalance: Double
    let monthlyBudget: Double
    let remainingBudget: Double
    let averageDailySpend: Double
    let projectedSpend: Double
    let previousMonthSpent: Double?
    let threeMonthAverageSpend: Double?
    let savingsRate: Double?
    let topCategory: String?
    let largestExpenseTitle: String?
    let largestExpenseAmount: Double?
    let activeExpenseDays: Int
    let remainingFixedCosts: Double
    let categoryTrends: [FinanceCategoryExportTrend]
}

struct FinanceCategoryExportTrend: Codable, Equatable {
    let category: String
    let spent: Double
    let share: Double
    let previousMonthSpent: Double?
    let changeFromPrevious: Double?
    let budget: Double?
    let isOverBudget: Bool
}

enum BackupImportSourceKind: String, Equatable {
    case json
    case sqlite
    case csvDirectory
}

struct BackupImportPreflightReport: Equatable {
    let sourceKind: BackupImportSourceKind
    let itemCounts: [String: Int]
    let warnings: [String]

    var totalItems: Int {
        itemCounts.values.reduce(0, +)
    }
}

enum BackupServiceError: LocalizedError, Equatable {
    case databaseUnavailable
    case databaseFileMissing
    case backupDirectoryUnavailable
    case backupIntegrityCheckFailed(String)
    case importSourceUnsupported
    case importSourceInvalid(String)

    var errorDescription: String? {
        switch self {
        case .databaseUnavailable:
            return "Die Datenbank ist nicht verfügbar."
        case .databaseFileMissing:
            return "Die Datenbankdatei wurde nicht gefunden."
        case .backupDirectoryUnavailable:
            return "Der Backup-Ordner konnte nicht erstellt werden."
        case .backupIntegrityCheckFailed:
            return "Das Backup konnte nicht geprüft werden."
        case .importSourceUnsupported:
            return "Dieses Importformat wird noch nicht unterstützt."
        case .importSourceInvalid:
            return "Die Importquelle konnte nicht geprüft werden."
        }
    }
}

struct BackupService {
    private let database: AppDatabase
    private let fileManager: FileManager
    private let backupDirectoryOverride: URL?
    private let now: () -> Date

    init(
        database: AppDatabase,
        fileManager: FileManager = .default,
        backupDirectory: URL? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        self.database = database
        self.fileManager = fileManager
        self.backupDirectoryOverride = backupDirectory
        self.now = now
    }

    func backupDirectoryURL() throws -> URL {
        let directory: URL
        if let backupDirectoryOverride {
            directory = backupDirectoryOverride
        } else {
            directory = try defaultBackupDirectoryURL()
        }

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        } catch {
            throw BackupServiceError.backupDirectoryUnavailable
        }
    }

    func createSQLiteBackup() throws -> URL {
        let sourceURL = try activeDatabaseURL()
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw BackupServiceError.databaseFileMissing
        }

        let directory = try backupDirectoryURL()
        let fileURL = directory.appendingPathComponent("AboLife-backup-\(timestamp()).sqlite", isDirectory: false)
        let temporaryURL = directory.appendingPathComponent(".\(fileURL.lastPathComponent).tmp", isDirectory: false)

        if fileManager.fileExists(atPath: temporaryURL.path) {
            try fileManager.removeItem(at: temporaryURL)
        }

        do {
            let destination = try DatabaseQueue(path: temporaryURL.path, configuration: DatabaseConfiguration.makeConfiguration())
            try database.writer.backup(to: destination)
        }
        try verifyBackupIntegrity(at: temporaryURL)

        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        try fileManager.moveItem(at: temporaryURL, to: fileURL)

        return fileURL
    }

    func createJSONExport() throws -> URL {
        let directory = try backupDirectoryURL()
        let fileURL = directory.appendingPathComponent("AboLife-export-\(timestamp()).json", isDirectory: false)
        let payload = try makeExportPayload()
        let data = try Self.jsonEncoder.encode(payload)
        try data.write(to: fileURL, options: [.atomic])
        return fileURL
    }

    func createMarkdownSummaryExport() throws -> URL {
        let directory = try backupDirectoryURL()
        let fileURL = directory.appendingPathComponent("AboLife-summary-\(timestamp()).md", isDirectory: false)
        let payload = try makeExportPayload()
        let markdown = markdownSummary(payload: payload, createdAt: now())
        try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    func createCSVExport() throws -> URL {
        let directory = try backupDirectoryURL()
        let createdAt = now()
        let exportDirectory = directory.appendingPathComponent("AboLife_Backup_\(backupTimestamp(createdAt))", isDirectory: true)
        let csvDirectory = exportDirectory.appendingPathComponent("csv", isDirectory: true)
        let reportsDirectory = exportDirectory.appendingPathComponent("reports", isDirectory: true)
        let chartsDirectory = reportsDirectory.appendingPathComponent("charts", isDirectory: true)
        let payload = try makeExportPayload()

        if fileManager.fileExists(atPath: exportDirectory.path) {
            try fileManager.removeItem(at: exportDirectory)
        }

        try fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: csvDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: chartsDirectory, withIntermediateDirectories: true)

        var files: [ExportManifestFile] = []
        let metadataRows = metadataRows(createdAt: createdAt)
        try writeCSVFile(
            relativePath: "metadata.csv",
            headers: ["key", "value"],
            rows: metadataRows,
            root: exportDirectory,
            files: &files,
            type: "metadata"
        )

        let habitRows = payload.habitEntries
            .filter { $0.habitKey != "training" }
            .map { entry in
                [
                    entry.id,
                    csvDate(entry.createdAt),
                    entry.date,
                    entry.habitKey,
                    habitTitle(for: entry.habitKey),
                    entry.isCompleted ? "done" : "missed",
                    csvOptional(entry.value),
                    entry.unit ?? "",
                    entry.note ?? "",
                    "manual"
                ]
            }

        try writeCSVFile(
            relativePath: "csv/nutrition_entries.csv",
            headers: ["id", "created_at", "entry_date", "meal_type", "title", "calories", "protein_g", "carbs_g", "fat_g", "notes", "source"],
            rows: payload.nutritionEntries.map {
                [$0.id, csvDate($0.createdAt), dayString($0.occurredAt), "", $0.title, "\($0.caloriesKcal)", csvNumber($0.proteinG), "", "", $0.note ?? "", "manual"]
            },
            root: exportDirectory,
            files: &files
        )
        try writeCSVFile(
            relativePath: "csv/weight_entries.csv",
            headers: ["id", "created_at", "entry_date", "weight_kg", "notes", "source"],
            rows: payload.weightEntries.map {
                [$0.id, csvDate($0.createdAt), $0.date, csvNumber($0.weightKg), "", "manual"]
            },
            root: exportDirectory,
            files: &files
        )
        try writeCSVFile(
            relativePath: "csv/workout_sessions.csv",
            headers: ["id", "created_at", "started_at", "ended_at", "entry_date", "title", "workout_type", "duration_min", "intensity", "pain_reported", "notes", "source"],
            rows: payload.workoutSessions.map {
                [$0.id, csvDate($0.createdAt), csvDate($0.occurredAt), "", dayString($0.occurredAt), $0.workoutType, $0.workoutType, "\($0.durationMin)", $0.workoutIntensity ?? "", "\($0.painReported)", $0.note ?? "", "manual"]
            },
            root: exportDirectory,
            files: &files
        )
        try writeCSVFile(
            relativePath: "csv/workout_exercises.csv",
            headers: ["id", "session_id", "exercise_name", "sort_order", "is_completed", "pain_reported", "notes"],
            rows: payload.workoutExercises.map {
                [$0.id, $0.sessionId, $0.exerciseName, "\($0.sortOrder)", "\($0.isCompleted)", "\($0.painReported)", $0.note ?? ""]
            },
            root: exportDirectory,
            files: &files
        )
        try writeCSVFile(
            relativePath: "csv/workout_sets.csv",
            headers: ["id", "exercise_id", "set_number", "reps", "weight_kg", "duration_sec", "rpe", "pain_reported", "notes"],
            rows: payload.workoutSets.map {
                [$0.id, $0.exerciseId, "\($0.setNumber)", csvOptionalInt($0.reps), csvOptional($0.weightKg), csvOptionalInt($0.durationSec), csvOptional($0.rpe), "\($0.painReported)", $0.note ?? ""]
            },
            root: exportDirectory,
            files: &files
        )
        try writeCSVFile(
            relativePath: "csv/finance_transactions.csv",
            headers: ["id", "created_at", "entry_date", "type", "category", "title", "amount", "currency", "notes", "source"],
            rows: payload.financeEntries.map {
                let isIncome = $0.amount < 0
                return [$0.id, csvDate($0.createdAt), dayString($0.occurredAt), isIncome ? "income" : "expense", $0.category, $0.title, csvNumber(abs($0.amount)), $0.currency, $0.note ?? "", "manual"]
            },
            root: exportDirectory,
            files: &files
        )
        try writeCSVFile(
            relativePath: "csv/finance_category_budgets.csv",
            headers: ["id", "created_at", "month_key", "category", "budget_amount", "currency"],
            rows: payload.financeCategoryBudgets.map {
                [$0.id, csvDate($0.createdAt), $0.monthKey, $0.category, csvNumber($0.budgetAmount), $0.currency]
            },
            root: exportDirectory,
            files: &files
        )
        try writeCSVFile(
            relativePath: "csv/finance_fixed_costs.csv",
            headers: ["id", "created_at", "title", "amount", "currency", "category", "due_day", "is_active", "notes"],
            rows: payload.financeFixedCosts.map {
                [$0.id, csvDate($0.createdAt), $0.title, csvNumber($0.amount), $0.currency, $0.category, "\($0.dueDay)", $0.isActive ? "true" : "false", $0.note ?? ""]
            },
            root: exportDirectory,
            files: &files
        )
        try writeCSVFile(
            relativePath: "csv/finance_savings_goals.csv",
            headers: ["id", "created_at", "title", "target_amount", "current_amount", "currency", "target_date", "is_active", "notes"],
            rows: payload.financeSavingsGoals.map {
                [$0.id, csvDate($0.createdAt), $0.title, csvNumber($0.targetAmount), csvNumber($0.currentAmount), $0.currency, $0.targetDate.map(csvDate) ?? "", $0.isActive ? "true" : "false", $0.note ?? ""]
            },
            root: exportDirectory,
            files: &files
        )
        try writeCSVFile(
            relativePath: "csv/finance_monthly_analysis.csv",
            headers: ["month", "currency", "spent", "income", "balance", "monthly_budget", "remaining_budget", "average_daily_spend", "projected_spend", "previous_month_spent", "three_month_average_spend", "savings_rate", "top_category", "largest_expense_title", "largest_expense_amount", "active_expense_days", "remaining_fixed_costs"],
            rows: payload.financeAnalysis.map {
                [[
                    $0.generatedForMonth,
                    $0.currency,
                    csvNumber($0.monthlySpent),
                    csvNumber($0.monthlyIncome),
                    csvNumber($0.monthlyBalance),
                    csvNumber($0.monthlyBudget),
                    csvNumber($0.remainingBudget),
                    csvNumber($0.averageDailySpend),
                    csvNumber($0.projectedSpend),
                    $0.previousMonthSpent.map(csvNumber) ?? "",
                    $0.threeMonthAverageSpend.map(csvNumber) ?? "",
                    $0.savingsRate.map(csvNumber) ?? "",
                    $0.topCategory ?? "",
                    $0.largestExpenseTitle ?? "",
                    $0.largestExpenseAmount.map(csvNumber) ?? "",
                    "\($0.activeExpenseDays)",
                    csvNumber($0.remainingFixedCosts)
                ]]
            } ?? [],
            root: exportDirectory,
            files: &files
        )
        try writeCSVFile(
            relativePath: "csv/finance_category_trends.csv",
            headers: ["category", "spent", "share", "previous_month_spent", "change_from_previous", "budget", "is_over_budget"],
            rows: payload.financeAnalysis?.categoryTrends.map {
                [
                    $0.category,
                    csvNumber($0.spent),
                    csvNumber($0.share),
                    $0.previousMonthSpent.map(csvNumber) ?? "",
                    $0.changeFromPrevious.map(csvNumber) ?? "",
                    $0.budget.map(csvNumber) ?? "",
                    $0.isOverBudget ? "true" : "false"
                ]
            } ?? [],
            root: exportDirectory,
            files: &files
        )
        try writeCSVFile(
            relativePath: "csv/habit_entries.csv",
            headers: ["id", "created_at", "entry_date", "habit_key", "habit_title", "status", "value", "unit", "notes", "source"],
            rows: habitRows,
            root: exportDirectory,
            files: &files
        )
        try writeCSVFile(
            relativePath: "csv/weekly_reviews.csv",
            headers: ["id", "created_at", "week_start", "week_end", "rating", "wins", "problems", "next_focus", "notes"],
            rows: payload.weeklyReviews.map {
                [$0.id, csvDate($0.createdAt), $0.weekStartDate, weekEndString($0.weekStartDate), $0.rating.map(String.init) ?? "", $0.winsText, $0.challengesText, $0.nextWeekFocusText, ""]
            },
            root: exportDirectory,
            files: &files
        )
        try writeCSVFile(
            relativePath: "csv/templates.csv",
            headers: ["id", "created_at", "template_type", "title", "payload", "is_active", "notes"],
            rows: payload.nutritionTemplates.map {
                [$0.id, csvDate($0.createdAt), $0.kind.rawValue, $0.name, templatePayload($0), "true", $0.note ?? ""]
            },
            root: exportDirectory,
            files: &files
        )

        let report = makeReportArtifacts(payload: payload, habitRows: habitRows, createdAt: createdAt)
        for chart in report.charts {
            let url = exportDirectory.appendingPathComponent(chart.name, isDirectory: false)
            try chart.svg.write(to: url, atomically: true, encoding: .utf8)
            files.append(ExportManifestFile(name: chart.name, type: "chart", rows: nil))
        }
        try report.html.write(to: reportsDirectory.appendingPathComponent("overview_report.html"), atomically: true, encoding: .utf8)
        files.append(ExportManifestFile(name: "reports/overview_report.html", type: "report", rows: nil))

        try markdownSummary(payload: payload, createdAt: createdAt).write(
            to: reportsDirectory.appendingPathComponent("summary.md"),
            atomically: true,
            encoding: .utf8
        )
        files.append(ExportManifestFile(name: "reports/summary.md", type: "markdown", rows: nil))

        let manifest = ExportManifest(
            appName: "AboLife",
            appVersion: appVersion(),
            schemaVersion: 1,
            createdAt: csvDate(createdAt),
            timezone: TimeZone.current.identifier,
            locale: Locale.current.identifier,
            csvSeparator: "semicolon",
            decimalSeparator: "dot",
            files: files,
            reports: [
                ExportManifestReport(name: "reports/overview_report.html", description: "Offline HTML overview report generated from backup data.")
            ],
            charts: report.charts.map { $0.manifest },
            warnings: report.warnings,
            excludedSensitiveFields: ["telegram_bot_token", "telegram_allowed_chat_id", "environment_variables"]
        )
        let manifestData = try Self.jsonEncoder.encode(manifest)
        try manifestData.write(to: exportDirectory.appendingPathComponent("export_manifest.json"), options: [.atomic])

        return exportDirectory
    }

    func makeExportPayload() throws -> AboLifeExportPayload {
        let createdAt = now()

        return try database.writer.read { db in
            let nutritionEntries = try fetchIfTableExists(NutritionEntryRecord.self, table: "nutrition_entries", db: db, orderSQL: "occurred_at ASC, id ASC")
            let nutritionTemplates = try fetchIfTableExists(NutritionTemplateRecord.self, table: "nutrition_templates", db: db, orderSQL: "updated_at ASC, name ASC, id ASC")
            let workoutSessions = try fetchIfTableExists(WorkoutSessionRecord.self, table: "workout_sessions", db: db, orderSQL: "occurred_at ASC, id ASC")
            let workoutExercises = try fetchIfTableExists(WorkoutExerciseRecord.self, table: "workout_exercises", db: db, orderSQL: "session_id ASC, sort_order ASC, id ASC")
            let workoutSets = try fetchIfTableExists(WorkoutSetRecord.self, table: "workout_sets", db: db, orderSQL: "exercise_id ASC, set_number ASC, id ASC")
            let financeEntries = try fetchIfTableExists(FinanceEntryRecord.self, table: "finance_entries", db: db, orderSQL: "occurred_at ASC, id ASC")
            let financeCategoryBudgets = try fetchIfTableExists(FinanceCategoryBudgetRecord.self, table: "finance_category_budgets", db: db, orderSQL: "month_key ASC, category ASC, id ASC")
            let financeFixedCosts = try fetchIfTableExists(FinanceFixedCostRecord.self, table: "finance_fixed_costs", db: db, orderSQL: "due_day ASC, title ASC, id ASC")
            let financeSavingsGoals = try fetchIfTableExists(FinanceSavingsGoalRecord.self, table: "finance_savings_goals", db: db, orderSQL: "is_active DESC, title ASC, id ASC")
            let settings = try fetchIfTableExists(AppSettingsRecord.self, table: "app_settings", db: db, orderSQL: "id ASC")
            return AboLifeExportPayload(
                exportVersion: 1,
                createdAt: createdAt,
                appName: "AboLife",
                nutritionEntries: nutritionEntries,
                nutritionTemplates: nutritionTemplates,
                workoutSessions: workoutSessions,
                workoutExercises: workoutExercises,
                workoutSets: workoutSets,
                financeEntries: financeEntries,
                financeCategoryBudgets: financeCategoryBudgets,
                financeFixedCosts: financeFixedCosts,
                financeSavingsGoals: financeSavingsGoals,
                financeAnalysis: makeFinanceAnalysis(
                    entries: financeEntries,
                    budgets: financeCategoryBudgets,
                    fixedCosts: financeFixedCosts,
                    settings: settings.first,
                    createdAt: createdAt
                ),
                habitEntries: try fetchIfTableExists(HabitEntryRecord.self, table: "habit_entries", db: db, orderSQL: "date ASC, habit_key ASC, id ASC"),
                weightEntries: try fetchIfTableExists(WeightEntryRecord.self, table: "weight_entries", db: db, orderSQL: "date ASC, id ASC"),
                bodyMetricEntries: try fetchIfTableExists(BodyMetricEntryRecord.self, table: "body_metric_entries", db: db, orderSQL: "occurred_at ASC, id ASC"),
                weeklyReviews: try fetchIfTableExists(WeeklyReviewRecord.self, table: "weekly_reviews", db: db, orderSQL: "week_start_date ASC, id ASC"),
                settings: settings
            )
        }
    }

    func preflightImport(from sourceURL: URL) throws -> BackupImportPreflightReport {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory) else {
            throw BackupServiceError.importSourceInvalid("Quelle wurde nicht gefunden.")
        }

        if isDirectory.boolValue {
            return try preflightCSVDirectory(sourceURL)
        }

        switch sourceURL.pathExtension.lowercased() {
        case "json":
            return try preflightJSON(sourceURL)
        case "sqlite", "db":
            return try preflightSQLite(sourceURL)
        default:
            throw BackupServiceError.importSourceUnsupported
        }
    }

    private func preflightJSON(_ url: URL) throws -> BackupImportPreflightReport {
        do {
            let data = try Data(contentsOf: url)
            let payload = try Self.jsonDecoder.decode(AboLifeExportPayload.self, from: data)
            return BackupImportPreflightReport(
                sourceKind: .json,
                itemCounts: itemCounts(payload),
                warnings: sensitiveImportWarnings()
            )
        } catch {
            throw BackupServiceError.importSourceInvalid("JSON-Export ist nicht lesbar.")
        }
    }

    private func preflightSQLite(_ url: URL) throws -> BackupImportPreflightReport {
        do {
            let queue = try DatabaseQueue(path: url.path, configuration: DatabaseConfiguration.makeConfiguration())
            let counts = try queue.read { db in
                var result: [String: Int] = [:]
                for table in Self.importableTables {
                    if try tableExists(table, db: db) {
                        result[table] = try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM \(table)") ?? 0
                    }
                }
                return result
            }
            guard !counts.isEmpty else {
                throw BackupServiceError.importSourceInvalid("SQLite-Datei enthält keine bekannten AboLife-Tabellen.")
            }
            return BackupImportPreflightReport(
                sourceKind: .sqlite,
                itemCounts: counts,
                warnings: sensitiveImportWarnings()
            )
        } catch let error as BackupServiceError {
            throw error
        } catch {
            throw BackupServiceError.importSourceInvalid("SQLite-Backup ist nicht lesbar.")
        }
    }

    private func preflightCSVDirectory(_ url: URL) throws -> BackupImportPreflightReport {
        let manifestURL = url.appendingPathComponent("export_manifest.json", isDirectory: false)
        let csvURL = url.appendingPathComponent("csv", isDirectory: true)
        guard fileManager.fileExists(atPath: manifestURL.path),
              fileManager.fileExists(atPath: csvURL.path) else {
            throw BackupServiceError.importSourceInvalid("CSV-Backup braucht export_manifest.json und einen csv-Ordner.")
        }

        do {
            let manifestData = try Data(contentsOf: manifestURL)
            let manifest = try Self.jsonDecoder.decode(ExportManifest.self, from: manifestData)
            let counts = Dictionary(
                uniqueKeysWithValues: manifest.files
                    .filter { $0.type == "csv" }
                    .map { ($0.name, $0.rows ?? 0) }
            )
            return BackupImportPreflightReport(
                sourceKind: .csvDirectory,
                itemCounts: counts,
                warnings: sensitiveImportWarnings()
            )
        } catch {
            throw BackupServiceError.importSourceInvalid("CSV-Manifest ist nicht lesbar.")
        }
    }

    private func itemCounts(_ payload: AboLifeExportPayload) -> [String: Int] {
        [
            "nutrition_entries": payload.nutritionEntries.count,
            "nutrition_templates": payload.nutritionTemplates.count,
            "workout_sessions": payload.workoutSessions.count,
            "workout_exercises": payload.workoutExercises.count,
            "workout_sets": payload.workoutSets.count,
            "finance_entries": payload.financeEntries.count,
            "finance_category_budgets": payload.financeCategoryBudgets.count,
            "finance_fixed_costs": payload.financeFixedCosts.count,
            "finance_savings_goals": payload.financeSavingsGoals.count,
            "habit_entries": payload.habitEntries.count,
            "weight_entries": payload.weightEntries.count,
            "body_metric_entries": payload.bodyMetricEntries.count,
            "weekly_reviews": payload.weeklyReviews.count,
            "app_settings": payload.settings.count
        ]
    }

    private func sensitiveImportWarnings() -> [String] {
        [
            "Import ist aktuell nur Vorprüfung; es werden keine lokalen Daten überschrieben.",
            "Telegram-Token und erlaubte Chat-ID werden nicht importiert oder exportiert."
        ]
    }

    private static let importableTables = [
        "nutrition_entries",
        "nutrition_templates",
        "workout_sessions",
        "workout_exercises",
        "workout_sets",
        "finance_entries",
        "finance_category_budgets",
        "finance_fixed_costs",
        "finance_savings_goals",
        "habit_entries",
        "weight_entries",
        "body_metric_entries",
        "weekly_reviews",
        "app_settings"
    ]

    private func metadataRows(createdAt: Date) -> [[String]] {
        [
            ["app_name", "AboLife"],
            ["app_version", appVersion()],
            ["export_schema_version", "1"],
            ["export_created_at", csvDate(createdAt)],
            ["timezone", TimeZone.current.identifier],
            ["locale", Locale.current.identifier],
            ["csv_separator", "semicolon"],
            ["decimal_separator", "dot"],
            ["contains_sensitive_data", "personal_entries_only"]
        ]
    }

    private func writeCSVFile(
        relativePath: String,
        headers: [String],
        rows: [[String]],
        root: URL,
        files: inout [ExportManifestFile],
        type: String = "csv"
    ) throws {
        let fileURL = root.appendingPathComponent(relativePath, isDirectory: false)
        let lines = ([headers] + rows)
            .map { $0.map(Self.escapeCSVField).joined(separator: ";") }
            .joined(separator: "\n") + "\n"
        try lines.write(to: fileURL, atomically: true, encoding: .utf8)
        files.append(ExportManifestFile(name: relativePath, type: type, rows: rows.count))
    }

    private func makeReportArtifacts(
        payload: AboLifeExportPayload,
        habitRows: [[String]],
        createdAt: Date
    ) -> BackupReportArtifacts {
        var warnings: [String] = []
        var charts: [GeneratedChart] = []
        let lastSevenDays = recentDayKeys(endingAt: createdAt, count: 7)

        let caloriesByDay = sumNutrition(payload.nutritionEntries, days: lastSevenDays, value: { Double($0.caloriesKcal) })
        charts.append(barChart(
            name: "reports/charts/nutrition_calories_7d.svg",
            title: "Kalorien pro Tag",
            unit: "kcal",
            values: caloriesByDay,
            dataSource: "csv/nutrition_entries.csv",
            period: "last_7_days",
            warnings: &warnings
        ))

        let proteinByDay = sumNutrition(payload.nutritionEntries, days: lastSevenDays, value: { $0.proteinG })
        charts.append(barChart(
            name: "reports/charts/nutrition_protein_7d.svg",
            title: "Protein pro Tag",
            unit: "g",
            values: proteinByDay,
            dataSource: "csv/nutrition_entries.csv",
            period: "last_7_days",
            warnings: &warnings
        ))

        charts.append(lineChart(
            name: "reports/charts/weight_trend.svg",
            title: "Gewichtstrend",
            unit: "kg",
            values: payload.weightEntries.map { ($0.date, $0.weightKg) },
            dataSource: "csv/weight_entries.csv",
            period: "all_entries",
            warnings: &warnings
        ))

        let expensesByMonth = monthlyExpenses(payload.financeEntries)
        charts.append(barChart(
            name: "reports/charts/finance_monthly_expenses.svg",
            title: "Ausgaben pro Monat",
            unit: payload.financeEntries.first?.currency ?? "EUR",
            values: expensesByMonth,
            dataSource: "csv/finance_transactions.csv",
            period: "all_entries",
            warnings: &warnings
        ))

        let categoryExpenses = expensesByCategory(payload.financeEntries)
        charts.append(barChart(
            name: "reports/charts/finance_expenses_by_category.svg",
            title: "Ausgaben nach Kategorie",
            unit: payload.financeEntries.first?.currency ?? "EUR",
            values: categoryExpenses,
            dataSource: "csv/finance_transactions.csv",
            period: "all_entries",
            warnings: &warnings
        ))

        charts.append(barChart(
            name: "reports/charts/habit_completion_7d.svg",
            title: "Habit-Erfüllung",
            unit: "%",
            values: habitCompletion(habitRows: habitRows, days: lastSevenDays),
            dataSource: "csv/habit_entries.csv",
            period: "last_7_days",
            warnings: &warnings
        ))

        charts.append(barChart(
            name: "reports/charts/training_sessions_4w.svg",
            title: "Trainings pro Woche",
            unit: "Einheiten",
            values: trainingSessions4W(payload.workoutSessions, endingAt: createdAt),
            dataSource: "csv/workout_sessions.csv",
            period: "last_4_weeks",
            warnings: &warnings
        ))

        let html = overviewHTML(payload: payload, charts: charts, createdAt: createdAt)
        return BackupReportArtifacts(html: html, charts: charts, warnings: warnings)
    }

    private func overviewHTML(payload: AboLifeExportPayload, charts: [GeneratedChart], createdAt: Date) -> String {
        let dataRange = containedDataRange(payload)
        let chartCards = charts.map { chart in
            """
            <section class="card">
              <h2>\(htmlEscape(chart.title))</h2>
              <img src="charts/\(URL(fileURLWithPath: chart.name).lastPathComponent)" alt="\(htmlEscape(chart.title))">
            </section>
            """
        }.joined(separator: "\n")

        return """
        <!doctype html>
        <html lang="de">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>AboLife Backup Report</title>
          <style>
            :root { color-scheme: light dark; --bg: #f7f7f4; --fg: #202124; --muted: #676b70; --card: #ffffff; --line: #d9d8d2; }
            @media (prefers-color-scheme: dark) { :root { --bg: #151617; --fg: #f2f0ea; --muted: #a9aaa8; --card: #202225; --line: #383a3d; } }
            body { margin: 0; padding: 32px; background: var(--bg); color: var(--fg); font: 15px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
            main { max-width: 1100px; margin: 0 auto; }
            header { margin-bottom: 24px; }
            h1 { font-size: 34px; margin: 0 0 8px; letter-spacing: 0; }
            h2 { font-size: 18px; margin: 0 0 14px; letter-spacing: 0; }
            p { color: var(--muted); margin: 0 0 8px; }
            .grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); gap: 12px; margin: 20px 0; }
            .card { background: var(--card); border: 1px solid var(--line); border-radius: 8px; padding: 18px; margin-bottom: 14px; }
            .metric { font-size: 28px; font-weight: 700; color: var(--fg); display: block; }
            img { display: block; width: 100%; height: auto; }
            ul { margin: 8px 0 0; padding-left: 18px; color: var(--muted); }
          </style>
        </head>
        <body>
        <main>
          <header>
            <h1>AboLife Backup Report</h1>
            <p>Exportiert am \(htmlEscape(csvDate(createdAt))) · App-Version \(htmlEscape(appVersion())) · Schema 1</p>
            <p>Zeitraum der Daten: \(htmlEscape(dataRange))</p>
          </header>
          <section class="grid">
            \(metricCard("Mahlzeiten", payload.nutritionEntries.count))
            \(metricCard("Gewichtseinträge", payload.weightEntries.count))
            \(metricCard("Trainings", payload.workoutSessions.count))
            \(metricCard("Trainingsübungen", payload.workoutExercises.count))
            \(metricCard("Trainingssätze", payload.workoutSets.count))
            \(metricCard("Finanztransaktionen", payload.financeEntries.count))
            \(metricCard("Finanzpläne", payload.financeCategoryBudgets.count + payload.financeFixedCosts.count + payload.financeSavingsGoals.count))
            \(metricCard("Habit-Einträge", payload.habitEntries.filter { $0.habitKey != "training" }.count))
            \(metricCard("Wochenreviews", payload.weeklyReviews.count))
          </section>
          \(financeAnalysisHTML(payload.financeAnalysis))
          \(chartCards)
          <section class="card">
            <h2>Hinweise</h2>
            <ul>
              <li>Dieser Report ist aus Backup-Rohdaten berechnet.</li>
              <li>Die CSV-Dateien sind die primäre Backup-Quelle.</li>
              <li>Geheime Konfigurationswerte wie Telegram Tokens werden nicht exportiert.</li>
            </ul>
          </section>
        </main>
        </body>
        </html>
        """
    }

    private func financeAnalysisHTML(_ analysis: FinanceExportAnalysis?) -> String {
        guard let analysis else {
            return """
            <section class="card"><h2>Finanzanalyse</h2><p>Noch nicht genug Finanzdaten für eine Monatsanalyse.</p></section>
            """
        }
        let trends = analysis.categoryTrends.prefix(5).map { trend in
            let budget = trend.budget.map { " · Budget \(csvNumber($0)) \(analysis.currency)" } ?? ""
            let previous = trend.changeFromPrevious.map { " · ggü. Vormonat \(csvNumber($0)) \(analysis.currency)" } ?? ""
            return "<li>\(htmlEscape(trend.category)): \(csvNumber(trend.spent)) \(htmlEscape(analysis.currency))\(budget)\(previous)</li>"
        }.joined()
        return """
        <section class="card">
          <h2>Finanzanalyse</h2>
          <p>Monat \(htmlEscape(analysis.generatedForMonth)): \(csvNumber(analysis.monthlySpent)) \(htmlEscape(analysis.currency)) Ausgaben · Prognose \(csvNumber(analysis.projectedSpend)) \(htmlEscape(analysis.currency)) · Restbudget \(csvNumber(analysis.remainingBudget)) \(htmlEscape(analysis.currency))</p>
          <p>Top-Kategorie: \(htmlEscape(analysis.topCategory ?? "noch offen")) · aktive Ausgabentage: \(analysis.activeExpenseDays) · ausstehende Fixkosten: \(csvNumber(analysis.remainingFixedCosts)) \(htmlEscape(analysis.currency))</p>
          <h2>Kategorie-Trends</h2>
          <ul>\(trends)</ul>
        </section>
        """
    }

    private func markdownSummary(payload: AboLifeExportPayload, createdAt: Date) -> String {
        let expenses = payload.financeEntries.filter { $0.amount >= 0 }.reduce(0) { $0 + $1.amount }
        let income = payload.financeEntries.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }
        return """
        # AboLife Backup Summary

        Exportiert am: \(csvDate(createdAt))
        Zeitraum: \(containedDataRange(payload))

        ## Inhalte

        - Mahlzeiten: \(payload.nutritionEntries.count)
        - Gewichtseintraege: \(payload.weightEntries.count)
        - Trainings: \(payload.workoutSessions.count)
        - Trainingsuebungen: \(payload.workoutExercises.count)
        - Trainingssaetze: \(payload.workoutSets.count)
        - Finanztransaktionen: \(payload.financeEntries.count)
        - Habit-Eintraege: \(payload.habitEntries.filter { $0.habitKey != "training" }.count)
        - Wochenreviews: \(payload.weeklyReviews.count)

        ## Finanzen

        - Einnahmen gesamt: \(csvNumber(income)) \(payload.financeEntries.first?.currency ?? "EUR")
        - Ausgaben gesamt: \(csvNumber(expenses)) \(payload.financeEntries.first?.currency ?? "EUR")
        \(markdownFinanceAnalysis(payload.financeAnalysis))

        ## Datenschutz

        Telegram-Token, erlaubte Chat-ID und lokale Environment-Werte werden nicht exportiert.
        """
    }

    private func markdownFinanceAnalysis(_ analysis: FinanceExportAnalysis?) -> String {
        guard let analysis else { return "- Monatsanalyse: noch nicht genug Daten" }
        let savings = analysis.savingsRate.map { "\n- Sparquote: \(csvNumber($0 * 100)) %" } ?? ""
        let categories = analysis.categoryTrends.prefix(5).map {
            "- \($0.category): \(csvNumber($0.spent)) \(analysis.currency)"
        }.joined(separator: "\n")
        return """

        - Monatsanalyse: \(analysis.generatedForMonth)
        - Ausgaben aktueller Monat: \(csvNumber(analysis.monthlySpent)) \(analysis.currency)
        - Prognose: \(csvNumber(analysis.projectedSpend)) \(analysis.currency)
        - Restbudget: \(csvNumber(analysis.remainingBudget)) \(analysis.currency)
        - Top-Kategorie: \(analysis.topCategory ?? "noch offen")
        - Ausstehende Fixkosten: \(csvNumber(analysis.remainingFixedCosts)) \(analysis.currency)\(savings)

        ### Kategorie-Trends

        \(categories.isEmpty ? "Noch keine Kategorie-Daten." : categories)
        """
    }

    private func metricCard(_ title: String, _ value: Int) -> String {
        """
        <section class="card"><span class="metric">\(value)</span><p>\(htmlEscape(title))</p></section>
        """
    }

    private func defaultBackupDirectoryURL() throws -> URL {
        let applicationSupportURL = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        return applicationSupportURL
            .appendingPathComponent(DatabaseConfiguration.applicationSupportFolderName, isDirectory: true)
            .appendingPathComponent("Backups", isDirectory: true)
    }

    private func verifyBackupIntegrity(at fileURL: URL) throws {
        let queue = try DatabaseQueue(path: fileURL.path, configuration: DatabaseConfiguration.makeConfiguration())
        let result: String = try queue.read { db in
            try String.fetchOne(db, sql: "PRAGMA integrity_check") ?? "missing"
        }

        guard result == "ok" else {
            throw BackupServiceError.backupIntegrityCheckFailed(result)
        }
    }

    private func activeDatabaseURL() throws -> URL {
        try database.writer.read { db in
            guard let row = try Row.fetchOne(db, sql: "PRAGMA database_list"),
                  let path: String = row["file"],
                  !path.isEmpty else {
                throw BackupServiceError.databaseUnavailable
            }
            return URL(fileURLWithPath: path)
        }
    }

    private func sumNutrition(
        _ entries: [NutritionEntryRecord],
        days: [String],
        value: (NutritionEntryRecord) -> Double
    ) -> [(String, Double)] {
        let grouped = Dictionary(grouping: entries, by: { dayString($0.occurredAt) })
            .mapValues { $0.reduce(0) { $0 + value($1) } }
        return days.map { ($0, grouped[$0] ?? 0) }
    }

    private func monthlyExpenses(_ entries: [FinanceEntryRecord]) -> [(String, Double)] {
        let grouped = Dictionary(grouping: entries.filter { $0.amount >= 0 }, by: { String(dayString($0.occurredAt).prefix(7)) })
            .mapValues { $0.reduce(0) { $0 + abs($1.amount) } }
        return grouped.keys.sorted().map { ($0, grouped[$0] ?? 0) }
    }

    private func makeFinanceAnalysis(
        entries: [FinanceEntryRecord],
        budgets: [FinanceCategoryBudgetRecord],
        fixedCosts: [FinanceFixedCostRecord],
        settings: AppSettingsRecord?,
        createdAt: Date
    ) -> FinanceExportAnalysis {
        let calendar = Calendar(identifier: .gregorian)
        let monthKey = String(dayString(createdAt).prefix(7))
        let previousMonthKey = calendar.date(byAdding: .month, value: -1, to: createdAt).map { String(dayString($0).prefix(7)) }
        let currentEntries = entries.filter { String(dayString($0.occurredAt).prefix(7)) == monthKey }
        let previousEntries = previousMonthKey.map { key in entries.filter { String(dayString($0.occurredAt).prefix(7)) == key } } ?? []
        let expenses = currentEntries.filter { $0.amount >= 0 }
        let previousExpenses = previousEntries.filter { $0.amount >= 0 }
        let monthlySpent = expenses.reduce(0) { $0 + $1.amount }
        let monthlyIncome = currentEntries.filter { $0.amount < 0 }.reduce(0) { $0 + abs($1.amount) }
        let monthlyBudget = settings?.monthlyBudget ?? 0
        let monthStart = calendar.dateInterval(of: .month, for: createdAt)?.start ?? createdAt
        let elapsedDays = max((calendar.dateComponents([.day], from: monthStart, to: calendar.startOfDay(for: createdAt)).day ?? 0) + 1, 1)
        let totalMonthDays = max(calendar.range(of: .day, in: .month, for: createdAt)?.count ?? elapsedDays, elapsedDays)
        let activeExpenseDays = Set(expenses.map { dayString($0.occurredAt) }).count
        let averageDailySpend = monthlySpent / Double(elapsedDays)
        let remainingFixedCosts = fixedCosts
            .filter(\.isActive)
            .filter { min(max($0.dueDay, 1), 31) >= calendar.component(.day, from: createdAt) }
            .reduce(0) { $0 + $1.amount }
        let projectedSpend = monthlySpent + averageDailySpend * Double(max(totalMonthDays - elapsedDays, 0)) + remainingFixedCosts
        let groupedCurrent = Dictionary(grouping: expenses, by: { FinanceCategoryCatalog.normalized($0.category, kind: .expense) })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        let groupedPrevious = Dictionary(grouping: previousExpenses, by: { FinanceCategoryCatalog.normalized($0.category, kind: .expense) })
            .mapValues { $0.reduce(0) { $0 + $1.amount } }
        let budgetByCategory = Dictionary(uniqueKeysWithValues: budgets.filter { $0.monthKey == monthKey }.map { (FinanceCategoryCatalog.normalized($0.category, kind: .expense), $0.budgetAmount) })
        let categories = Set(groupedCurrent.keys).union(groupedPrevious.keys).union(budgetByCategory.keys)
        let categoryTrends = categories.map { category in
            let spent = groupedCurrent[category] ?? 0
            let previous = groupedPrevious[category]
            let budget = budgetByCategory[category]
            return FinanceCategoryExportTrend(
                category: category,
                spent: spent,
                share: monthlySpent > 0 ? spent / monthlySpent : 0,
                previousMonthSpent: previous,
                changeFromPrevious: previous.map { spent - $0 },
                budget: budget,
                isOverBudget: budget.map { spent > $0 } ?? false
            )
        }.sorted {
            if $0.spent == $1.spent { return $0.category < $1.category }
            return $0.spent > $1.spent
        }
        let monthlyTotals = monthlyExpenses(entries).suffix(3).map(\.1)
        let largestExpense = expenses.max { $0.amount < $1.amount }

        return FinanceExportAnalysis(
            generatedForMonth: monthKey,
            currency: settings?.defaultCurrency ?? entries.first?.currency ?? "EUR",
            monthlySpent: monthlySpent,
            monthlyIncome: monthlyIncome,
            monthlyBalance: monthlyIncome - monthlySpent,
            monthlyBudget: monthlyBudget,
            remainingBudget: max(monthlyBudget - monthlySpent, 0),
            averageDailySpend: averageDailySpend,
            projectedSpend: projectedSpend,
            previousMonthSpent: previousEntries.isEmpty ? nil : previousExpenses.reduce(0) { $0 + $1.amount },
            threeMonthAverageSpend: monthlyTotals.count >= 3 ? monthlyTotals.reduce(0, +) / Double(monthlyTotals.count) : nil,
            savingsRate: monthlyIncome > 0 ? max((monthlyIncome - monthlySpent) / monthlyIncome, 0) : nil,
            topCategory: categoryTrends.first(where: { $0.spent > 0 })?.category,
            largestExpenseTitle: largestExpense?.title,
            largestExpenseAmount: largestExpense?.amount,
            activeExpenseDays: activeExpenseDays,
            remainingFixedCosts: remainingFixedCosts,
            categoryTrends: categoryTrends
        )
    }

    private func expensesByCategory(_ entries: [FinanceEntryRecord]) -> [(String, Double)] {
        let grouped = Dictionary(grouping: entries.filter { $0.amount >= 0 }, by: { $0.category.isEmpty ? "Ohne Kategorie" : $0.category })
            .mapValues { $0.reduce(0) { $0 + abs($1.amount) } }
        return grouped
            .map { ($0.key, $0.value) }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 { return lhs.0 < rhs.0 }
                return lhs.1 > rhs.1
            }
    }

    private func habitCompletion(habitRows: [[String]], days: [String]) -> [(String, Double)] {
        days.map { day in
            let rows = habitRows.filter { $0.indices.contains(2) && $0[2] == day }
            guard !rows.isEmpty else { return (day, 0) }
            let done = rows.filter { $0.indices.contains(5) && $0[5] == "done" }.count
            return (day, Double(done) / Double(rows.count) * 100)
        }
    }

    private func trainingSessions4W(_ sessions: [WorkoutSessionRecord], endingAt: Date) -> [(String, Double)] {
        let calendar = Calendar(identifier: .gregorian)
        let weekStarts = (0..<4).reversed().compactMap { offset -> Date? in
            guard let date = calendar.date(byAdding: .weekOfYear, value: -offset, to: endingAt) else { return nil }
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start
        }
        return weekStarts.map { weekStart in
            let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            let count = sessions.filter { $0.status == "done" && $0.occurredAt >= weekStart && $0.occurredAt < weekEnd }.count
            return ("KW \(calendar.component(.weekOfYear, from: weekStart))", Double(count))
        }
    }

    private func barChart(
        name: String,
        title: String,
        unit: String,
        values: [(String, Double)],
        dataSource: String,
        period: String,
        warnings: inout [String]
    ) -> GeneratedChart {
        let hasData = values.contains { $0.1 > 0 }
        if !hasData {
            warnings.append("No data available for \(URL(fileURLWithPath: name).lastPathComponent)")
        }
        let svg = hasData ? makeBarSVG(title: title, unit: unit, values: values) : emptySVG(title: title)
        return GeneratedChart(
            name: name,
            title: title,
            svg: svg,
            manifest: ExportManifestChart(name: name, dataSource: dataSource, period: period, dataPoints: values.count)
        )
    }

    private func lineChart(
        name: String,
        title: String,
        unit: String,
        values: [(String, Double)],
        dataSource: String,
        period: String,
        warnings: inout [String]
    ) -> GeneratedChart {
        let sorted = values.sorted { $0.0 < $1.0 }
        if sorted.isEmpty {
            warnings.append("No weight entries available for \(URL(fileURLWithPath: name).lastPathComponent)")
        }
        let svg = sorted.isEmpty ? emptySVG(title: title) : makeLineSVG(title: title, unit: unit, values: sorted)
        return GeneratedChart(
            name: name,
            title: title,
            svg: svg,
            manifest: ExportManifestChart(name: name, dataSource: dataSource, period: period, dataPoints: sorted.count)
        )
    }

    private func makeBarSVG(title: String, unit: String, values: [(String, Double)]) -> String {
        let width = 760.0
        let left = 58.0
        let top = 54.0
        let chartHeight = 190.0
        let maxValue = Swift.max(values.map(\.1).max() ?? 1, 1)
        let slot = (width - left - 28) / Double(Swift.max(values.count, 1))
        let bars: String = values.enumerated().map { index, item -> String in
            let barHeight = item.1 / maxValue * chartHeight
            let x = left + Double(index) * slot + 8
            let y = top + chartHeight - barHeight
            let barWidth = Swift.max(slot - 16, 12)
            return """
            <rect x="\(svgNumber(x))" y="\(svgNumber(y))" width="\(svgNumber(barWidth))" height="\(svgNumber(barHeight))" rx="5" fill="#4f7f71"/>
            <text x="\(svgNumber(x + barWidth / 2))" y="282" text-anchor="middle">\(htmlEscape(shortLabel(item.0)))</text>
            """
        }.joined(separator: "\n")
        return chartShell(title: title, unit: unit, body: bars, maxValue: maxValue)
    }

    private func makeLineSVG(title: String, unit: String, values: [(String, Double)]) -> String {
        let width = 760.0
        let left = 58.0
        let top = 54.0
        let chartHeight = 190.0
        let minValue = values.map(\.1).min() ?? 0
        let maxValue = values.map(\.1).max() ?? 1
        let range = Swift.max(maxValue - minValue, 1)
        let step = (width - left - 44) / Double(Swift.max(values.count - 1, 1))
        let points = values.enumerated().map { index, item -> (Double, Double, String) in
            let x = left + Double(index) * step
            let y = top + chartHeight - ((item.1 - minValue) / range * chartHeight)
            return (x, y, item.0)
        }
        let pointString = points.map { "\(svgNumber($0.0)),\(svgNumber($0.1))" }.joined(separator: " ")
        let circles = points.map {
            """
            <circle cx="\(svgNumber($0.0))" cy="\(svgNumber($0.1))" r="4" fill="#4f7f71"/>
            <text x="\(svgNumber($0.0))" y="282" text-anchor="middle">\(htmlEscape(shortLabel($0.2)))</text>
            """
        }.joined(separator: "\n")
        return chartShell(
            title: title,
            unit: unit,
            body: "<polyline points=\"\(pointString)\" fill=\"none\" stroke=\"#4f7f71\" stroke-width=\"4\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>\n\(circles)",
            maxValue: maxValue
        )
    }

    private func chartShell(title: String, unit: String, body: String, maxValue: Double) -> String {
        """
        <svg xmlns="http://www.w3.org/2000/svg" width="760" height="320" viewBox="0 0 760 320" role="img" aria-label="\(htmlEscape(title))">
          <rect width="760" height="320" rx="14" fill="#fbfaf7"/>
          <text x="28" y="34" font-family="-apple-system, BlinkMacSystemFont, Segoe UI, sans-serif" font-size="22" font-weight="700" fill="#202124">\(htmlEscape(title))</text>
          <text x="28" y="58" font-family="-apple-system, BlinkMacSystemFont, Segoe UI, sans-serif" font-size="13" fill="#676b70">Einheit: \(htmlEscape(unit)) · Max: \(csvNumber(maxValue))</text>
          <line x1="58" y1="244" x2="732" y2="244" stroke="#d9d8d2" stroke-width="2"/>
          <line x1="58" y1="54" x2="58" y2="244" stroke="#d9d8d2" stroke-width="2"/>
          <g font-family="-apple-system, BlinkMacSystemFont, Segoe UI, sans-serif" font-size="12" fill="#676b70">\(body)</g>
        </svg>
        """
    }

    private func emptySVG(title: String) -> String {
        """
        <svg xmlns="http://www.w3.org/2000/svg" width="760" height="320" viewBox="0 0 760 320" role="img" aria-label="\(htmlEscape(title))">
          <rect width="760" height="320" rx="14" fill="#fbfaf7"/>
          <text x="28" y="38" font-family="-apple-system, BlinkMacSystemFont, Segoe UI, sans-serif" font-size="22" font-weight="700" fill="#202124">\(htmlEscape(title))</text>
          <rect x="230" y="120" width="300" height="78" rx="10" fill="#ffffff" stroke="#d9d8d2"/>
          <text x="380" y="166" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, Segoe UI, sans-serif" font-size="16" fill="#676b70">Keine Daten vorhanden.</text>
        </svg>
        """
    }

    private func fetchIfTableExists<Record: FetchableRecord>(
        _ type: Record.Type,
        table: String,
        db: Database,
        orderSQL: String
    ) throws -> [Record] {
        guard try tableExists(table, db: db) else { return [] }
        return try Record.fetchAll(db, sql: "SELECT * FROM \(table) ORDER BY \(orderSQL)")
    }

    private func tableExists(_ table: String, db: Database) throws -> Bool {
        try String.fetchOne(
            db,
            sql: "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
            arguments: [table]
        ) != nil
    }

    private func timestamp() -> String {
        Self.fileNameFormatter.string(from: now())
    }

    private func backupTimestamp(_ date: Date) -> String {
        Self.backupNameFormatter.string(from: date)
    }

    private func csvDate(_ date: Date) -> String {
        Self.isoFormatter.string(from: date)
    }

    private func dayString(_ date: Date) -> String {
        Self.dayFormatter.string(from: date)
    }

    private func csvOptional(_ value: Double?) -> String {
        guard let value, value.isFinite else { return "" }
        return csvNumber(value)
    }

    private func csvOptional(_ value: Int?) -> String {
        value.map(String.init) ?? ""
    }

    private func csvOptionalInt(_ value: Int?) -> String {
        guard let value else { return "" }
        return "\(value)"
    }

    private func csvNumber(_ value: Double) -> String {
        guard value.isFinite else { return "" }
        return String(format: "%.6g", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private func svgNumber(_ value: Double) -> String {
        String(format: "%.2f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private func recentDayKeys(endingAt date: Date, count: Int) -> [String] {
        let calendar = Calendar(identifier: .gregorian)
        return (0..<count).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: date).map(dayString)
        }
    }

    private func weekEndString(_ weekStart: String) -> String {
        guard let date = Self.dayFormatter.date(from: weekStart),
              let end = Calendar(identifier: .gregorian).date(byAdding: .day, value: 6, to: date) else {
            return ""
        }
        return dayString(end)
    }

    private func templatePayload(_ template: NutritionTemplateRecord) -> String {
        [
            "calories=\(template.caloriesKcal)",
            "protein_g=\(csvNumber(template.proteinG))",
            "default_portion=\(template.defaultPortion ?? "")",
            "meal_type=\(template.mealType ?? "")"
        ].joined(separator: ";")
    }

    private func habitTitle(for key: String) -> String {
        FixedHabit.defaultDefinition(for: key)?.title ?? key
    }

    private func shortLabel(_ label: String) -> String {
        if label.count <= 10 { return label }
        return String(label.suffix(5))
    }

    private func containedDataRange(_ payload: AboLifeExportPayload) -> String {
        var days: [String] = []
        days.append(contentsOf: payload.nutritionEntries.map { dayString($0.occurredAt) })
        days.append(contentsOf: payload.weightEntries.map(\.date))
        days.append(contentsOf: payload.workoutSessions.map { dayString($0.occurredAt) })
        days.append(contentsOf: payload.financeEntries.map { dayString($0.occurredAt) })
        days.append(contentsOf: payload.habitEntries.map(\.date))
        days.append(contentsOf: payload.weeklyReviews.map(\.weekStartDate))
        let sorted = days.sorted()
        guard let first = sorted.first, let last = sorted.last else { return "Keine Daten vorhanden" }
        return first == last ? first : "\(first) bis \(last)"
    }

    private func appVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private func htmlEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func escapeCSVField(_ field: String) -> String {
        guard field.contains(";") || field.contains("\"") || field.contains("\n") || field.contains("\r") else {
            return field
        }

        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static let fileNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()

    private static let backupNameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static let isoFormatter = ISO8601DateFormatter()
}

private struct ExportManifest: Codable, Equatable {
    let appName: String
    let appVersion: String
    let schemaVersion: Int
    let createdAt: String
    let timezone: String
    let locale: String
    let csvSeparator: String
    let decimalSeparator: String
    let files: [ExportManifestFile]
    let reports: [ExportManifestReport]
    let charts: [ExportManifestChart]
    let warnings: [String]
    let excludedSensitiveFields: [String]
}

private struct ExportManifestFile: Codable, Equatable {
    let name: String
    let type: String
    let rows: Int?
}

private struct ExportManifestReport: Codable, Equatable {
    let name: String
    let description: String
}

private struct ExportManifestChart: Codable, Equatable {
    let name: String
    let dataSource: String
    let period: String
    let dataPoints: Int
}

private struct GeneratedChart {
    let name: String
    let title: String
    let svg: String
    let manifest: ExportManifestChart
}

private struct BackupReportArtifacts {
    let html: String
    let charts: [GeneratedChart]
    let warnings: [String]
}
