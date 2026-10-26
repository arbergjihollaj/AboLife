import Foundation

protocol TelegramFileClient {
    func getFile(fileId: String) async throws -> TelegramFile
    func downloadFile(filePath: String) async throws -> Data
}

struct TelegramBarcodeFoodScanService {
    let fileClient: TelegramFileClient
    let scanner: BarcodeScanning
    let lookupService: FoodProductLookingUp
    var temporaryDirectory: URL = FileManager.default.temporaryDirectory
    var fileManager: FileManager = .default
    var uniqueIdentifier: () -> String = { UUID().uuidString.lowercased() }
    var cleanupFailureLogger: (String) -> Void = { message in
        NSLog("%@", message)
    }

    func scan(photoSizes: [TelegramPhotoSize]) async -> Result<FoodProductLookupResult, TelegramBarcodeFoodScanFailure> {
        guard let photo = photoSizes.max(by: { $0.pixelArea < $1.pixelArea }) else {
            return .failure(.noPhoto)
        }

        let file: TelegramFile
        do {
            file = try await fileClient.getFile(fileId: photo.fileId)
        } catch {
            return .failure(.download("Ich konnte das Foto nicht von Telegram laden. Bitte versuche es erneut."))
        }

        let data: Data
        do {
            data = try await fileClient.downloadFile(filePath: file.filePath)
        } catch {
            return .failure(.download("Ich konnte das Foto nicht von Telegram laden. Bitte versuche es erneut."))
        }

        let imageURL = temporaryDirectory
            .appendingPathComponent("abolife_barcode_\(safeIdentifier())")
            .appendingPathExtension("jpg")

        do {
            try fileManager.createDirectory(
                at: temporaryDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            return .failure(.download("Das Foto konnte gerade nicht vorbereitet werden. Bitte versuche es noch einmal."))
        }

        defer {
            if fileManager.fileExists(atPath: imageURL.path) {
                do {
                    try fileManager.removeItem(at: imageURL)
                } catch {
                    cleanupFailureLogger("Temporäres Telegram-Barcode-Foto konnte nicht gelöscht werden.")
                }
            }
        }

        do {
            try data.write(to: imageURL, options: .atomic)
        } catch {
            return .failure(.download("Das Foto konnte gerade nicht vorbereitet werden. Bitte versuche es noch einmal."))
        }

        let scanResult: BarcodeScanResult
        do {
            scanResult = try await scanner.scanBarcode(in: imageURL)
        } catch let error as BarcodeScanError {
            return .failure(.barcode(Self.message(for: error)))
        } catch {
            return .failure(.barcode("Auf dem Foto war kein Barcode sicher erkennbar. Bitte sende ein nahes, scharfes Bild."))
        }

        do {
            return .success(try await lookupService.lookup(barcode: scanResult.value))
        } catch let error as FoodProductLookupError {
            return .failure(.lookup(Self.message(for: error)))
        } catch {
            return .failure(.lookup("Die Produktdaten sind gerade nicht verfügbar. Bitte versuche es später noch einmal."))
        }
    }

    private func safeIdentifier() -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let sanitized = uniqueIdentifier()
            .unicodeScalars
            .filter { allowed.contains($0) }
            .map(String.init)
            .joined()
        return sanitized.isEmpty ? UUID().uuidString.lowercased() : String(sanitized.prefix(64))
    }

    private static func message(for error: BarcodeScanError) -> String {
        switch error {
        case .unreadableImage:
            return "Das Foto war nicht gut lesbar. Bitte sende ein scharfes, gut beleuchtetes Bild."
        case .noBarcode:
            return "Auf dem Foto war kein Barcode sicher erkennbar. Bitte sende ein nahes, scharfes Bild."
        }
    }

    private static func message(for error: FoodProductLookupError) -> String {
        switch error {
        case .invalidBarcode:
            return "Der erkannte Barcode konnte nicht geprüft werden. Bitte fotografiere ihn noch einmal."
        case .notFound:
            return "Zu diesem Barcode wurden keine Produktdaten gefunden. Du kannst die Mahlzeit weiterhin manuell eintragen."
        case .invalidResponse:
            return "Die Produktdaten waren unvollständig. Bitte versuche es später noch einmal."
        case .network:
            return "Die Produktdaten sind gerade nicht verfügbar. Bitte versuche es später noch einmal."
        }
    }
}

enum TelegramBarcodeFoodScanFailure: Error, Equatable {
    case noPhoto
    case download(String)
    case barcode(String)
    case lookup(String)

    var message: String {
        switch self {
        case .noPhoto:
            return "Bitte sende ein Barcode-Foto."
        case let .download(message), let .barcode(message), let .lookup(message):
            return message
        }
    }
}
