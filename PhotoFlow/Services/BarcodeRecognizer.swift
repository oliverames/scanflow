//
//  BarcodeRecognizer.swift
//  ScanFlow
//
//  Barcode recognition service for document organization and metadata
//  Supports 1D (UPC, EAN, Code 39, Code 128) and 2D (QR, Data Matrix, PDF417) barcodes
//

import Foundation
#if os(macOS)
import AppKit
import Vision
#endif

#if os(macOS)

/// Barcode recognition for scanned documents
@MainActor
class BarcodeRecognizer {

    /// Recognized barcode information
    struct RecognizedBarcode: Identifiable {
        let id = UUID()
        let type: VNBarcodeSymbology
        let payload: String
        let confidence: Float
        let bounds: CGRect

        var typeDescription: String {
            switch type {
            case .upce: return "UPC-E"
            case .code39: return "Code 39"
            case .code39Checksum: return "Code 39 (Checksum)"
            case .code39FullASCII: return "Code 39 (Full ASCII)"
            case .code39FullASCIIChecksum: return "Code 39 (Full ASCII + Checksum)"
            case .code93: return "Code 93"
            case .code93i: return "Code 93i"
            case .code128: return "Code 128"
            case .dataMatrix: return "Data Matrix"
            case .ean8: return "EAN-8"
            case .ean13: return "EAN-13"
            case .i2of5: return "Interleaved 2 of 5"
            case .i2of5Checksum: return "Interleaved 2 of 5 (Checksum)"
            case .itf14: return "ITF-14"
            case .pdf417: return "PDF417"
            case .qr: return "QR Code"
            case .aztec: return "Aztec"
            case .codabar: return "Codabar"
            case .gs1DataBar: return "GS1 DataBar"
            case .gs1DataBarExpanded: return "GS1 DataBar Expanded"
            case .gs1DataBarLimited: return "GS1 DataBar Limited"
            case .microPDF417: return "MicroPDF417"
            case .microQR: return "Micro QR"
            default: return "Unknown"
            }
        }
    }

    // MARK: - Barcode Detection

    /// Detect all barcodes in an image
    func detectBarcodes(in image: NSImage) async throws -> [RecognizedBarcode] {
        guard let ciImage = CIImage(data: image.tiffRepresentation!) else {
            throw BarcodeError.invalidImage
        }

        let request = VNDetectBarcodesRequest()

        // Configure to recognize all supported symbologies
        request.symbologies = [
            // 1D Barcodes
            .upce,
            .code39,
            .code39Checksum,
            .code39FullASCII,
            .code39FullASCIIChecksum,
            .code93,
            .code93i,
            .code128,
            .ean8,
            .ean13,
            .i2of5,
            .i2of5Checksum,
            .itf14,
            .codabar,
            .gs1DataBar,
            .gs1DataBarExpanded,
            .gs1DataBarLimited,

            // 2D Barcodes
            .qr,
            .aztec,
            .pdf417,
            .dataMatrix,
            .microPDF417,
            .microQR
        ]

        // Optimize for accuracy
        request.revision = VNDetectBarcodesRequestRevision3

        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        try handler.perform([request])

        guard let observations = request.results else {
            return []
        }

        let imageSize = ciImage.extent.size

        return observations.compactMap { observation in
            guard let payload = observation.payloadStringValue,
                  !payload.isEmpty else {
                return nil
            }

            // Convert normalized coordinates to image coordinates
            let boundingBox = observation.boundingBox
            let bounds = CGRect(
                x: boundingBox.origin.x * imageSize.width,
                y: boundingBox.origin.y * imageSize.height,
                width: boundingBox.size.width * imageSize.width,
                height: boundingBox.size.height * imageSize.height
            )

            return RecognizedBarcode(
                type: observation.symbology,
                payload: payload,
                confidence: observation.confidence,
                bounds: bounds
            )
        }
    }

    /// Find first barcode of a specific type
    func findBarcode(ofType type: VNBarcodeSymbology, in image: NSImage) async throws -> RecognizedBarcode? {
        let barcodes = try await detectBarcodes(in: image)
        return barcodes.first { $0.type == type }
    }

    /// Find first QR code
    func findQRCode(in image: NSImage) async throws -> RecognizedBarcode? {
        return try await findBarcode(ofType: .qr, in: image)
    }

    // MARK: - Barcode-Based Document Organization

    /// Generate filename from barcode
    func generateFilename(from barcode: RecognizedBarcode, format: ScanFormat) -> String {
        let sanitized = barcode.payload.replacingOccurrences(of: "[^a-zA-Z0-9-_]", with: "_", options: .regularExpression)
        let timestamp = Date().timeIntervalSince1970
        return "\(sanitized)_\(Int(timestamp)).\(format.rawValue.lowercased())"
    }

    /// Determine folder path from barcode
    func folderPath(from barcode: RecognizedBarcode, basePath: String) -> String {
        // Use first 3 characters of barcode for folder organization
        let prefix = String(barcode.payload.prefix(3))
        return "\(basePath)/\(prefix)"
    }

    /// Check if barcode should trigger batch split
    func shouldSplitBatch(barcode: RecognizedBarcode, splitPattern: String?) -> Bool {
        guard let pattern = splitPattern, !pattern.isEmpty else {
            return false
        }

        // Check if barcode payload matches split pattern (supports regex)
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(barcode.payload.startIndex..., in: barcode.payload)
            return regex.firstMatch(in: barcode.payload, options: [], range: range) != nil
        }

        return false
    }

    // MARK: - Barcode Metadata

    /// Create metadata dictionary from barcode
    func metadata(from barcode: RecognizedBarcode) -> [String: Any] {
        return [
            "BarcodeType": barcode.typeDescription,
            "BarcodeValue": barcode.payload,
            "BarcodeConfidence": barcode.confidence,
            "BarcodeSymbology": barcode.type.rawValue
        ]
    }
}

// MARK: - Barcode Settings

/// Barcode recognition configuration
struct BarcodeSettings: Codable {
    var enabled: Bool = false
    var useForNaming: Bool = false
    var useForSplitting: Bool = false
    var splitPattern: String? = nil
    var useForFolderRouting: Bool = false
    var addToMetadata: Bool = true
    var minimumConfidence: Float = 0.5

    /// Preferred symbologies (empty = all)
    var preferredSymbologies: [String] = []
}

// MARK: - Errors

enum BarcodeError: LocalizedError {
    case invalidImage
    case noBarcodesFound
    case lowConfidence

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image for barcode recognition"
        case .noBarcodesFound:
            return "No barcodes detected in image"
        case .lowConfidence:
            return "Barcode confidence below threshold"
        }
    }
}

#endif
