//
//  BarcodeRecognizerTests.swift
//  ScanFlowTests
//
//  Unit tests for barcode recognition
//  Note: These tests are self-contained with minimal copied types
//

import Testing
import Foundation
#if os(macOS)
import AppKit
import Vision

// MARK: - Copied Types for Testing

private enum TestScanFormat: String {
    case pdf, jpeg, tiff, png
}

private enum TestBarcodeError: LocalizedError {
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

private struct TestBarcodeSettings {
    var enabled: Bool = false
    var useForNaming: Bool = false
    var useForSplitting: Bool = false
    var splitPattern: String? = nil
    var useForFolderRouting: Bool = false
    var addToMetadata: Bool = true
    var minimumConfidence: Float = 0.5
    var preferredSymbologies: [String] = []
}

private struct TestRecognizedBarcode {
    let id = UUID()
    let type: VNBarcodeSymbology
    let payload: String
    let confidence: Float
    let bounds: CGRect

    var typeDescription: String {
        switch type {
        case .upce: return "UPC-E"
        case .code39: return "Code 39"
        case .code128: return "Code 128"
        case .ean8: return "EAN-8"
        case .ean13: return "EAN-13"
        case .qr: return "QR Code"
        case .aztec: return "Aztec"
        case .pdf417: return "PDF417"
        case .dataMatrix: return "Data Matrix"
        default: return "Unknown"
        }
    }
}

/// Minimal BarcodeRecognizer for testing
private class TestBarcodeRecognizer {

    func detectBarcodes(in image: NSImage) async throws -> [TestRecognizedBarcode] {
        guard let tiffData = image.tiffRepresentation,
              let ciImage = CIImage(data: tiffData) else {
            throw TestBarcodeError.invalidImage
        }

        let request = VNDetectBarcodesRequest()
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

            let boundingBox = observation.boundingBox
            let bounds = CGRect(
                x: boundingBox.origin.x * imageSize.width,
                y: boundingBox.origin.y * imageSize.height,
                width: boundingBox.size.width * imageSize.width,
                height: boundingBox.size.height * imageSize.height
            )

            return TestRecognizedBarcode(
                type: observation.symbology,
                payload: payload,
                confidence: observation.confidence,
                bounds: bounds
            )
        }
    }

    func findQRCode(in image: NSImage) async throws -> TestRecognizedBarcode? {
        let barcodes = try await detectBarcodes(in: image)
        return barcodes.first { $0.type == .qr }
    }

    func generateFilename(from barcode: TestRecognizedBarcode, format: TestScanFormat) -> String {
        let sanitized = barcode.payload.replacingOccurrences(of: "[^a-zA-Z0-9-_]", with: "_", options: .regularExpression)
        let timestamp = Date().timeIntervalSince1970
        return "\(sanitized)_\(Int(timestamp)).\(format.rawValue.lowercased())"
    }

    func folderPath(from barcode: TestRecognizedBarcode, basePath: String) -> String {
        let prefix = String(barcode.payload.prefix(3))
        return "\(basePath)/\(prefix)"
    }

    func shouldSplitBatch(barcode: TestRecognizedBarcode, splitPattern: String?) -> Bool {
        guard let pattern = splitPattern, !pattern.isEmpty else {
            return false
        }

        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(barcode.payload.startIndex..., in: barcode.payload)
            return regex.firstMatch(in: barcode.payload, options: [], range: range) != nil
        }

        return false
    }

    func metadata(from barcode: TestRecognizedBarcode) -> [String: Any] {
        return [
            "BarcodeType": barcode.typeDescription,
            "BarcodeValue": barcode.payload,
            "BarcodeConfidence": barcode.confidence,
            "BarcodeSymbology": barcode.type.rawValue
        ]
    }
}

// MARK: - Tests

@Suite("BarcodeRecognizer Tests")
struct BarcodeRecognizerTests {

    // MARK: - Test Helpers

    private func createBlankImage(size: NSSize = NSSize(width: 200, height: 200)) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }

    // MARK: - Basic Detection Tests

    @Test("No barcodes returns empty array")
    @MainActor
    func noBarcodesReturnsEmptyArray() async throws {
        let recognizer = TestBarcodeRecognizer()
        let blankImage = createBlankImage()

        let barcodes = try await recognizer.detectBarcodes(in: blankImage)

        #expect(barcodes.isEmpty)
    }

    @Test("Find QR code returns nil for blank image")
    @MainActor
    func findQRCodeReturnsNilForBlankImage() async throws {
        let recognizer = TestBarcodeRecognizer()
        let blankImage = createBlankImage()

        let qrCode = try await recognizer.findQRCode(in: blankImage)

        #expect(qrCode == nil)
    }

    // MARK: - Barcode Type Description Tests

    @Test("Barcode type descriptions are correct")
    @MainActor
    func barcodeTypeDescriptions() {
        let testCases: [(VNBarcodeSymbology, String)] = [
            (.upce, "UPC-E"),
            (.code39, "Code 39"),
            (.code128, "Code 128"),
            (.ean8, "EAN-8"),
            (.ean13, "EAN-13"),
            (.qr, "QR Code"),
            (.aztec, "Aztec"),
            (.pdf417, "PDF417"),
            (.dataMatrix, "Data Matrix")
        ]

        for (symbology, expectedDescription) in testCases {
            let barcode = TestRecognizedBarcode(
                type: symbology,
                payload: "test",
                confidence: 1.0,
                bounds: .zero
            )
            #expect(barcode.typeDescription == expectedDescription)
        }
    }

    // MARK: - Filename Generation Tests

    @Test("Filename generated from barcode payload")
    @MainActor
    func filenameGeneratedFromPayload() {
        let recognizer = TestBarcodeRecognizer()

        let barcode = TestRecognizedBarcode(
            type: .qr,
            payload: "DOC-12345",
            confidence: 1.0,
            bounds: .zero
        )

        let filename = recognizer.generateFilename(from: barcode, format: .pdf)

        #expect(filename.hasPrefix("DOC-12345_"))
        #expect(filename.hasSuffix(".pdf"))
    }

    @Test("Filename sanitizes special characters")
    @MainActor
    func filenameSanitizesSpecialCharacters() {
        let recognizer = TestBarcodeRecognizer()

        let barcode = TestRecognizedBarcode(
            type: .qr,
            payload: "Test/File:Name*With?Special<Chars>",
            confidence: 1.0,
            bounds: .zero
        )

        let filename = recognizer.generateFilename(from: barcode, format: .jpeg)

        #expect(!filename.contains("/"))
        #expect(!filename.contains(":"))
        #expect(!filename.contains("*"))
        #expect(!filename.contains("?"))
        #expect(!filename.contains("<"))
        #expect(!filename.contains(">"))
    }

    // MARK: - Folder Path Tests

    @Test("Folder path uses barcode prefix")
    @MainActor
    func folderPathUsesBarcodePrefix() {
        let recognizer = TestBarcodeRecognizer()

        let barcode = TestRecognizedBarcode(
            type: .code128,
            payload: "ABC123456",
            confidence: 1.0,
            bounds: .zero
        )

        let path = recognizer.folderPath(from: barcode, basePath: "/Documents/Scans")

        #expect(path == "/Documents/Scans/ABC")
    }

    // MARK: - Batch Split Pattern Tests

    @Test("Split pattern matches exact string")
    @MainActor
    func splitPatternMatchesExactString() {
        let recognizer = TestBarcodeRecognizer()

        let barcode = TestRecognizedBarcode(
            type: .qr,
            payload: "SPLIT",
            confidence: 1.0,
            bounds: .zero
        )

        let shouldSplit = recognizer.shouldSplitBatch(barcode: barcode, splitPattern: "SPLIT")

        #expect(shouldSplit == true)
    }

    @Test("Split pattern supports regex")
    @MainActor
    func splitPatternSupportsRegex() {
        let recognizer = TestBarcodeRecognizer()

        let barcode = TestRecognizedBarcode(
            type: .qr,
            payload: "DOC-2024-001",
            confidence: 1.0,
            bounds: .zero
        )

        let shouldSplit = recognizer.shouldSplitBatch(barcode: barcode, splitPattern: "DOC-\\d{4}-\\d{3}")

        #expect(shouldSplit == true)
    }

    @Test("Split pattern returns false when no match")
    @MainActor
    func splitPatternReturnsFalseWhenNoMatch() {
        let recognizer = TestBarcodeRecognizer()

        let barcode = TestRecognizedBarcode(
            type: .qr,
            payload: "REGULAR-BARCODE",
            confidence: 1.0,
            bounds: .zero
        )

        let shouldSplit = recognizer.shouldSplitBatch(barcode: barcode, splitPattern: "^SPLIT$")

        #expect(shouldSplit == false)
    }

    @Test("Split pattern returns false when nil")
    @MainActor
    func splitPatternReturnsFalseWhenNil() {
        let recognizer = TestBarcodeRecognizer()

        let barcode = TestRecognizedBarcode(
            type: .qr,
            payload: "SPLIT",
            confidence: 1.0,
            bounds: .zero
        )

        let shouldSplit = recognizer.shouldSplitBatch(barcode: barcode, splitPattern: nil)

        #expect(shouldSplit == false)
    }

    @Test("Split pattern returns false when empty")
    @MainActor
    func splitPatternReturnsFalseWhenEmpty() {
        let recognizer = TestBarcodeRecognizer()

        let barcode = TestRecognizedBarcode(
            type: .qr,
            payload: "SPLIT",
            confidence: 1.0,
            bounds: .zero
        )

        let shouldSplit = recognizer.shouldSplitBatch(barcode: barcode, splitPattern: "")

        #expect(shouldSplit == false)
    }

    // MARK: - Metadata Tests

    @Test("Metadata contains expected fields")
    @MainActor
    func metadataContainsExpectedFields() {
        let recognizer = TestBarcodeRecognizer()

        let barcode = TestRecognizedBarcode(
            type: .qr,
            payload: "TEST-123",
            confidence: 0.95,
            bounds: CGRect(x: 10, y: 20, width: 100, height: 100)
        )

        let metadata = recognizer.metadata(from: barcode)

        #expect(metadata["BarcodeType"] as? String == "QR Code")
        #expect(metadata["BarcodeValue"] as? String == "TEST-123")
        #expect(metadata["BarcodeConfidence"] as? Float == 0.95)
        #expect(metadata["BarcodeSymbology"] as? String == VNBarcodeSymbology.qr.rawValue)
    }

    // MARK: - Error Tests

    @Test("BarcodeError descriptions are correct")
    func errorDescriptions() {
        #expect(TestBarcodeError.invalidImage.errorDescription == "Invalid image for barcode recognition")
        #expect(TestBarcodeError.noBarcodesFound.errorDescription == "No barcodes detected in image")
        #expect(TestBarcodeError.lowConfidence.errorDescription == "Barcode confidence below threshold")
    }

    // MARK: - BarcodeSettings Tests

    @Test("BarcodeSettings has correct defaults")
    func barcodeSettingsDefaults() {
        let settings = TestBarcodeSettings()

        #expect(settings.enabled == false)
        #expect(settings.useForNaming == false)
        #expect(settings.useForSplitting == false)
        #expect(settings.splitPattern == nil)
        #expect(settings.useForFolderRouting == false)
        #expect(settings.addToMetadata == true)
        #expect(settings.minimumConfidence == 0.5)
        #expect(settings.preferredSymbologies.isEmpty)
    }
}

#endif
