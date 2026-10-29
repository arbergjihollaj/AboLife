import Foundation
import GRDB

enum NutritionTemplateKind: String, Codable, CaseIterable {
    case favorite
    case mealTemplate = "meal_template"

    var title: String {
        switch self {
        case .favorite:
            return "Favorit"
        case .mealTemplate:
            return "Vorlage"
        }
    }
}

struct NutritionTemplateRecord: Codable, FetchableRecord, PersistableRecord, Identifiable, Equatable {
    static let databaseTableName = "nutrition_templates"

    var id: String
    var kind: NutritionTemplateKind
    var name: String
    var caloriesKcal: Int
    var proteinG: Double
    var defaultPortion: String?
    var mealType: String?
    var note: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = UUID().uuidString,
        kind: NutritionTemplateKind = .favorite,
        name: String,
        caloriesKcal: Int,
        proteinG: Double,
        defaultPortion: String? = nil,
        mealType: String? = nil,
        note: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.caloriesKcal = caloriesKcal
        self.proteinG = proteinG
        self.defaultPortion = defaultPortion
        self.mealType = mealType
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case kind
        case name
        case caloriesKcal = "calories_kcal"
        case proteinG = "protein_g"
        case defaultPortion = "default_portion"
        case mealType = "meal_type"
        case note
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
