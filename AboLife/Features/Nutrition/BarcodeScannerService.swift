import AppKit
import Foundation
import Vision

struct BarcodeScanResult: Equatable {
    let value: String
    let symbology: String
}

enum BarcodeScanError: LocalizedError, Equatable {
    case unreadableImage
    case noBarcode

    var errorDescription: String? {
        switch self {
        case .unreadableImage:
            return "Ich konnte das Barcode-Foto nicht lesen. Bitte sende ein scharfes, gut beleuchtetes Bild."
        case .noBarcode:
            return "Ich konnte auf dem Foto keinen Barcode erkennen. Bitte sende den Barcode möglichst nah und scharf."
        }
    }
}

protocol BarcodeScanning {
    func scanBarcode(in imageURL: URL) async throws -> BarcodeScanResult
}

struct BarcodeScannerService: BarcodeScanning {
    func scanBarcode(in imageURL: URL) async throws -> BarcodeScanResult {
        guard let image = NSImage(contentsOf: imageURL),
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw BarcodeScanError.unreadableImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = (request.results as? [VNBarcodeObservation]) ?? []
                let supported = observations
                    .filter { observation in
                        guard let payload = observation.payloadStringValue, !payload.isEmpty else { return false }
                        return Self.supportedSymbologies.contains(observation.symbology)
                    }
                    .sorted { $0.confidence > $1.confidence }

                guard let best = supported.first,
                      let value = best.payloadStringValue else {
                    continuation.resume(throwing: BarcodeScanError.noBarcode)
                    return
                }

                continuation.resume(
                    returning: BarcodeScanResult(
                        value: value,
                        symbology: best.symbology.rawValue
                    )
                )
            }
            request.symbologies = Array(Self.supportedSymbologies)

            do {
                try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    static var isAvailable: Bool {
        true
    }

    private static let supportedSymbologies: Set<VNBarcodeSymbology> = [
        .ean13,
        .ean8,
        .upce,
        .code128
    ]
}
