import Foundation

struct FoodProductLookupResult: Equatable {
    let barcode: String
    let name: String
    let brand: String?
    let quantityText: String?
    let caloriesPer100g: Double?
    let proteinPer100g: Double?
    let carbsPer100g: Double?
    let fatPer100g: Double?
    let source: String
}

enum FoodProductLookupError: LocalizedError, Equatable {
    case invalidBarcode
    case notFound(String)
    case invalidResponse
    case network

    var errorDescription: String? {
        switch self {
        case .invalidBarcode:
            return "Der Barcode konnte nicht für die Produktsuche verwendet werden."
        case let .notFound(barcode):
            return "Ich habe für Barcode \(barcode) kein Produkt bei Open Food Facts gefunden. Du kannst die Mahlzeit manuell eintragen."
        case .invalidResponse:
            return "Open Food Facts hat gerade keine verwertbaren Produktdaten geliefert."
        case .network:
            return "Open Food Facts ist gerade nicht erreichbar. Bitte versuche es später erneut."
        }
    }
}

protocol FoodProductLookingUp {
    func lookup(barcode: String) async throws -> FoodProductLookupResult
}

protocol FoodProductLookupNetworkSession {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

extension URLSession: FoodProductLookupNetworkSession {}

struct FoodProductLookupService: FoodProductLookingUp {
    var session: FoodProductLookupNetworkSession = URLSession.shared
    var decoder = JSONDecoder()

    func lookup(barcode: String) async throws -> FoodProductLookupResult {
        let cleanBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanBarcode.isEmpty,
              cleanBarcode.allSatisfy(\.isNumber),
              let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(cleanBarcode).json") else {
            throw FoodProductLookupError.invalidBarcode
        }

        do {
            let (data, response) = try await session.data(from: url)
            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                throw FoodProductLookupError.network
            }
            return try Self.parse(data: data, barcode: cleanBarcode, decoder: decoder)
        } catch let error as FoodProductLookupError {
            throw error
        } catch is DecodingError {
            throw FoodProductLookupError.invalidResponse
        } catch {
            throw FoodProductLookupError.network
        }
    }

    static func parse(data: Data, barcode: String? = nil, decoder: JSONDecoder = JSONDecoder()) throws -> FoodProductLookupResult {
        let response = try decoder.decode(OpenFoodFactsResponse.self, from: data)
        let responseBarcode = response.code ?? barcode ?? ""
        guard response.status == 1, let product = response.product else {
            throw FoodProductLookupError.notFound(responseBarcode)
        }
        let name = firstNonEmpty(product.productName, product.genericName) ?? "Unbekanntes Produkt"
        return FoodProductLookupResult(
            barcode: responseBarcode,
            name: name,
            brand: firstNonEmpty(product.brands),
            quantityText: firstNonEmpty(product.quantity),
            caloriesPer100g: product.nutriments.energyKcal100g,
            proteinPer100g: product.nutriments.proteins100g,
            carbsPer100g: product.nutriments.carbohydrates100g,
            fatPer100g: product.nutriments.fat100g,
            source: "open_food_facts"
        )
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        values
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}

private struct OpenFoodFactsResponse: Decodable {
    let code: String?
    let status: Int
    let product: OpenFoodFactsProduct?
}

private struct OpenFoodFactsProduct: Decodable {
    let productName: String?
    let genericName: String?
    let brands: String?
    let quantity: String?
    let nutriments: OpenFoodFactsNutriments

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case genericName = "generic_name"
        case brands
        case quantity
        case nutriments
    }
}

private struct OpenFoodFactsNutriments: Decodable {
    let energyKcal100g: Double?
    let proteins100g: Double?
    let carbohydrates100g: Double?
    let fat100g: Double?

    enum CodingKeys: String, CodingKey {
        case energyKcal100g = "energy-kcal_100g"
        case proteins100g = "proteins_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case fat100g = "fat_100g"
    }
}
