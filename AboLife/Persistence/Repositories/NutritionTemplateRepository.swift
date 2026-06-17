import Foundation
import GRDB

enum NutritionTemplateValidationError: LocalizedError, Equatable {
    case emptyName
    case invalidCalories
    case invalidProtein
    case caloriesTooHigh
    case proteinTooHigh

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Bitte gib einen Namen ein."
        case .invalidCalories:
            return "Kalorien müssen 0 oder mehr sein."
        case .invalidProtein:
            return "Protein muss 0 oder mehr sein."
        case .caloriesTooHigh:
            return "Bitte prüfe die Kalorien. Der Wert wirkt zu hoch."
        case .proteinTooHigh:
            return "Bitte prüfe das Protein. Der Wert wirkt zu hoch."
        }
    }
}

struct NutritionTemplateRepository {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    @discardableResult
    func create(
        kind: NutritionTemplateKind,
        name: String,
        caloriesKcal: Int,
        proteinG: Double,
        defaultPortion: String? = nil,
        mealType: String? = nil,
        note: String? = nil
    ) throws -> NutritionTemplateRecord {
        try Self.validate(name: name, caloriesKcal: caloriesKcal, proteinG: proteinG)
        let now = Date()
        let entry = NutritionTemplateRecord(
            kind: kind,
            name: Self.trimmedName(name),
            caloriesKcal: caloriesKcal,
            proteinG: proteinG,
            defaultPortion: Self.optionalTrimmed(defaultPortion),
            mealType: Self.optionalTrimmed(mealType),
            note: Self.optionalTrimmed(note),
            createdAt: now,
            updatedAt: now
        )

        try database.writer.write { db in
            try entry.insert(db)
        }
        return entry
    }

    @discardableResult
    func update(
        id: String,
        kind: NutritionTemplateKind,
        name: String,
        caloriesKcal: Int,
        proteinG: Double,
        defaultPortion: String? = nil,
        mealType: String? = nil,
        note: String? = nil
    ) throws -> NutritionTemplateRecord? {
        try Self.validate(name: name, caloriesKcal: caloriesKcal, proteinG: proteinG)
        let now = Date()

        return try database.writer.write { db in
            guard var existing = try NutritionTemplateRecord.fetchOne(db, key: id) else { return nil }
            existing.kind = kind
            existing.name = Self.trimmedName(name)
            existing.caloriesKcal = caloriesKcal
            existing.proteinG = proteinG
            existing.defaultPortion = Self.optionalTrimmed(defaultPortion)
            existing.mealType = Self.optionalTrimmed(mealType)
            existing.note = Self.optionalTrimmed(note)
            existing.updatedAt = now
            try existing.update(db)
            return existing
        }
    }

    func fetchAll() throws -> [NutritionTemplateRecord] {
        try database.writer.read { db in
            try NutritionTemplateRecord
                .order(Column("updated_at").desc, Column("name"))
                .fetchAll(db)
        }
    }

    func fetch(kind: NutritionTemplateKind) throws -> [NutritionTemplateRecord] {
        try database.writer.read { db in
            try NutritionTemplateRecord
                .filter(Column("kind") == kind.rawValue)
                .order(Column("updated_at").desc, Column("name"))
                .fetchAll(db)
        }
    }

    func fetch(id: String) throws -> NutritionTemplateRecord? {
        try database.writer.read { db in
            try NutritionTemplateRecord.fetchOne(db, key: id)
        }
    }

    @discardableResult
    func addMeal(from template: NutritionTemplateRecord, date: Date = Date(), calendar: Calendar = .current) throws -> NutritionEntryRecord {
        let interval = DateIntervals.day(containing: date, calendar: calendar)
        let occurredAt = calendar.date(
            bySettingHour: calendar.component(.hour, from: Date()),
            minute: calendar.component(.minute, from: Date()),
            second: 0,
            of: interval.start
        ) ?? date
        let meal = NutritionEntryRecord(
            occurredAt: occurredAt,
            title: template.name,
            caloriesKcal: template.caloriesKcal,
            proteinG: template.proteinG,
            note: template.note
        )

        try database.writer.write { db in
            try meal.insert(db)
        }
        return meal
    }

    @discardableResult
    func addMeal(templateID: String, date: Date = Date(), calendar: Calendar = .current) throws -> NutritionEntryRecord? {
        guard let template = try fetch(id: templateID) else { return nil }
        return try addMeal(from: template, date: date, calendar: calendar)
    }

    @discardableResult
    func addMeal(
        from template: NutritionTemplateRecord,
        date: Date = Date(),
        title: String,
        caloriesKcal: Int,
        proteinG: Double,
        note: String? = nil,
        calendar: Calendar = .current
    ) throws -> NutritionEntryRecord {
        try Self.validate(name: title, caloriesKcal: caloriesKcal, proteinG: proteinG)
        let interval = DateIntervals.day(containing: date, calendar: calendar)
        let occurredAt = calendar.date(
            bySettingHour: calendar.component(.hour, from: Date()),
            minute: calendar.component(.minute, from: Date()),
            second: 0,
            of: interval.start
        ) ?? date
        let meal = NutritionEntryRecord(
            occurredAt: occurredAt,
            title: Self.trimmedName(title),
            caloriesKcal: caloriesKcal,
            proteinG: proteinG,
            note: Self.optionalTrimmed(note) ?? template.note
        )

        try database.writer.write { db in
            try meal.insert(db)
        }
        return meal
    }

    func delete(id: String) throws {
        try database.writer.write { db in
            _ = try NutritionTemplateRecord.deleteOne(db, key: id)
        }
    }

    func deleteAll() throws {
        try database.writer.write { db in
            _ = try NutritionTemplateRecord.deleteAll(db)
        }
    }

    static func validate(name: String, caloriesKcal: Int, proteinG: Double) throws {
        guard !trimmedName(name).isEmpty else { throw NutritionTemplateValidationError.emptyName }
        guard caloriesKcal >= 0 else { throw NutritionTemplateValidationError.invalidCalories }
        guard proteinG.isFinite, proteinG >= 0 else { throw NutritionTemplateValidationError.invalidProtein }
        guard caloriesKcal <= 5_000 else { throw NutritionTemplateValidationError.caloriesTooHigh }
        guard proteinG <= 400 else { throw NutritionTemplateValidationError.proteinTooHigh }
    }

    static func trimmedName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func optionalTrimmed(_ value: String?) -> String? {
        let trimmed = (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
