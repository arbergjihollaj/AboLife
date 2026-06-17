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
            .appendingPathComponent("abolife_barcode_\(UUID().uuidString)")
            .appendingPathExtension("jpg")
        do {
            try data.write(to: imageURL, options: .atomic)
        } catch {
            return .failure(.download("Ich konnte das Foto nicht lokal vorbereiten. Bitte versuche es erneut."))
        }

        defer {
            try? FileManager.default.removeItem(at: imageURL)
        }

        let scanResult: BarcodeScanResult
        do {
            scanResult = try await scanner.scanBarcode(in: imageURL)
        } catch let error as BarcodeScanError {
            return .failure(.barcode(error.localizedDescription))
        } catch {
            return .failure(.barcode("Ich konnte auf dem Foto keinen Barcode erkennen. Bitte sende den Barcode möglichst nah und scharf."))
        }

        do {
            return .success(try await lookupService.lookup(barcode: scanResult.value))
        } catch let error as FoodProductLookupError {
            return .failure(.lookup(error.localizedDescription))
        } catch {
            return .failure(.lookup("Open Food Facts ist gerade nicht erreichbar. Bitte versuche es später erneut."))
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
