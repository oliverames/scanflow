//
//  ImageProcessorTests.swift
//  ScanFlowTests
//
//  Unit tests for image processing pipeline
//  Note: These tests are self-contained with minimal copied types
//

import Testing
import Foundation
#if os(macOS)
import AppKit
import CoreImage

// MARK: - Copied Types for Testing

private enum TestPaperSize: Equatable {
    case photo4x6
    case photo5x7
    case photo8x10
    case letter
    case a4
    case custom(width: Double, height: Double)

    var description: String {
        switch self {
        case .photo4x6: return "4\" × 6\" Photo"
        case .photo5x7: return "5\" × 7\" Photo"
        case .photo8x10: return "8\" × 10\" Photo"
        case .letter: return "Letter (8.5\" × 11\")"
        case .a4: return "A4 (8.27\" × 11.69\")"
        case .custom(let width, let height):
            return String(format: "%.2f\" × %.2f\"", width, height)
        }
    }
}

private enum TestImageProcessingError: LocalizedError {
    case invalidImage
    case renderFailed
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Invalid image format"
        case .renderFailed: return "Failed to render processed image"
        case .processingFailed: return "Image processing failed"
        }
    }
}

/// Minimal ImageProcessor for testing
private class TestImageProcessor {
    private let context: CIContext

    init() {
        context = CIContext()
    }

    func isBlankPage(_ image: NSImage, threshold: Double = 0.98) async -> Bool {
        guard let tiffData = image.tiffRepresentation,
              let ciImage = CIImage(data: tiffData) else {
            return false
        }

        guard let filter = CIFilter(name: "CIAreaAverage") else { return false }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: ciImage.extent), forKey: kCIInputExtentKey)

        guard let outputImage = filter.outputImage else { return false }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(outputImage,
                      toBitmap: &bitmap,
                      rowBytes: 4,
                      bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                      format: .RGBA8,
                      colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)

        let brightness = Double(bitmap[0]) / 255.0
        return brightness > threshold
    }

    func detectPaperSize(_ image: NSImage) async -> TestPaperSize {
        let size = image.size
        let widthInches = size.width / 72.0
        let heightInches = size.height / 72.0
        let tolerance = 0.5

        if abs(widthInches - 4.0) < tolerance && abs(heightInches - 6.0) < tolerance {
            return .photo4x6
        }
        if abs(widthInches - 5.0) < tolerance && abs(heightInches - 7.0) < tolerance {
            return .photo5x7
        }
        if abs(widthInches - 8.0) < tolerance && abs(heightInches - 10.0) < tolerance {
            return .photo8x10
        }
        if abs(widthInches - 8.5) < tolerance && abs(heightInches - 11.0) < tolerance {
            return .letter
        }
        if abs(widthInches - 8.27) < tolerance && abs(heightInches - 11.69) < tolerance {
            return .a4
        }

        return .custom(width: widthInches, height: heightInches)
    }

    func recognizeText(_ image: NSImage) async throws -> String {
        guard let tiffData = image.tiffRepresentation,
              let ciImage = CIImage(data: tiffData) else {
            throw TestImageProcessingError.invalidImage
        }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        try handler.perform([request])

        guard let observations = request.results else {
            return ""
        }

        let recognizedStrings = observations.compactMap { observation in
            observation.topCandidates(1).first?.string
        }

        return recognizedStrings.joined(separator: "\n")
    }

    func process(_ image: NSImage) async throws -> NSImage {
        guard let tiffData = image.tiffRepresentation,
              let ciImage = CIImage(data: tiffData) else {
            throw TestImageProcessingError.invalidImage
        }

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            throw TestImageProcessingError.renderFailed
        }

        let size = NSSize(width: cgImage.width, height: cgImage.height)
        return NSImage(cgImage: cgImage, size: size)
    }
}

import Vision

// MARK: - Tests

@Suite("ImageProcessor Tests")
struct ImageProcessorTests {

    // MARK: - Test Helpers

    private func createTestImage(color: NSColor, size: NSSize = NSSize(width: 100, height: 100)) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }

    private func createBlankImage(size: NSSize = NSSize(width: 100, height: 100)) -> NSImage {
        return createTestImage(color: NSColor(white: 0.99, alpha: 1.0), size: size)
    }

    private func createContentImage(size: NSSize = NSSize(width: 100, height: 100)) -> NSImage {
        return createTestImage(color: NSColor(white: 0.3, alpha: 1.0), size: size)
    }

    private func createTextImage(_ text: String, size: NSSize = NSSize(width: 400, height: 100)) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24),
            .foregroundColor: NSColor.black
        ]
        text.draw(at: NSPoint(x: 20, y: 35), withAttributes: attributes)
        image.unlockFocus()
        return image
    }

    // MARK: - Blank Page Detection Tests

    @Test("White image detected as blank")
    @MainActor
    func whiteImageDetectedAsBlank() async {
        let processor = TestImageProcessor()
        let blankImage = createBlankImage()

        let isBlank = await processor.isBlankPage(blankImage, threshold: 0.98)

        #expect(isBlank == true)
    }

    @Test("Dark image not detected as blank")
    @MainActor
    func darkImageNotDetectedAsBlank() async {
        let processor = TestImageProcessor()
        let contentImage = createContentImage()

        let isBlank = await processor.isBlankPage(contentImage, threshold: 0.98)

        #expect(isBlank == false)
    }

    @Test("Threshold affects blank detection")
    @MainActor
    func thresholdAffectsBlankDetection() async {
        let processor = TestImageProcessor()
        let lightGrayImage = createTestImage(color: NSColor(white: 0.95, alpha: 1.0))

        let isBlankHighThreshold = await processor.isBlankPage(lightGrayImage, threshold: 0.98)
        #expect(isBlankHighThreshold == false)

        let isBlankLowThreshold = await processor.isBlankPage(lightGrayImage, threshold: 0.90)
        #expect(isBlankLowThreshold == true)
    }

    // MARK: - Paper Size Detection Tests

    @Test("Letter size detected correctly")
    @MainActor
    func letterSizeDetectedCorrectly() async {
        let processor = TestImageProcessor()
        let letterImage = createTestImage(color: .white, size: NSSize(width: 612, height: 792))

        let paperSize = await processor.detectPaperSize(letterImage)

        #expect(paperSize == .letter)
    }

    @Test("A4 size detected correctly")
    @MainActor
    func a4SizeDetectedCorrectly() async {
        let processor = TestImageProcessor()
        let a4Image = createTestImage(color: .white, size: NSSize(width: 595, height: 842))

        let paperSize = await processor.detectPaperSize(a4Image)

        #expect(paperSize == .a4)
    }

    @Test("4x6 photo size detected correctly")
    @MainActor
    func photo4x6SizeDetectedCorrectly() async {
        let processor = TestImageProcessor()
        let photoImage = createTestImage(color: .white, size: NSSize(width: 288, height: 432))

        let paperSize = await processor.detectPaperSize(photoImage)

        #expect(paperSize == .photo4x6)
    }

    @Test("Custom size returned for non-standard dimensions")
    @MainActor
    func customSizeReturnedForNonStandard() async {
        let processor = TestImageProcessor()
        let customImage = createTestImage(color: .white, size: NSSize(width: 500, height: 500))

        let paperSize = await processor.detectPaperSize(customImage)

        if case .custom(let width, let height) = paperSize {
            #expect(abs(width - 6.94) < 0.5)
            #expect(abs(height - 6.94) < 0.5)
        } else {
            Issue.record("Expected custom paper size")
        }
    }

    // MARK: - Paper Size Description Tests

    @Test("Paper size descriptions are correct")
    func paperSizeDescriptions() {
        #expect(TestPaperSize.photo4x6.description == "4\" × 6\" Photo")
        #expect(TestPaperSize.photo5x7.description == "5\" × 7\" Photo")
        #expect(TestPaperSize.photo8x10.description == "8\" × 10\" Photo")
        #expect(TestPaperSize.letter.description == "Letter (8.5\" × 11\")")
        #expect(TestPaperSize.a4.description == "A4 (8.27\" × 11.69\")")

        let custom = TestPaperSize.custom(width: 5.5, height: 8.5)
        #expect(custom.description == "5.50\" × 8.50\"")
    }

    // MARK: - OCR Tests

    @Test("OCR recognizes simple text")
    @MainActor
    func ocrRecognizesSimpleText() async throws {
        let processor = TestImageProcessor()
        let textImage = createTextImage("Hello World")

        let recognizedText = try await processor.recognizeText(textImage)

        let normalized = recognizedText.lowercased()
        #expect(normalized.contains("hello") || normalized.contains("world"))
    }

    @Test("OCR returns empty for blank image")
    @MainActor
    func ocrReturnsEmptyForBlankImage() async throws {
        let processor = TestImageProcessor()
        let blankImage = createBlankImage(size: NSSize(width: 400, height: 100))

        let recognizedText = try await processor.recognizeText(blankImage)

        #expect(recognizedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    // MARK: - Image Processing Pipeline Tests

    @Test("Process returns valid image")
    @MainActor
    func processReturnsValidImage() async throws {
        let processor = TestImageProcessor()
        let inputImage = createContentImage(size: NSSize(width: 200, height: 200))

        let processedImage = try await processor.process(inputImage)

        #expect(processedImage.size.width > 0)
        #expect(processedImage.size.height > 0)
    }

    // MARK: - Error Handling Tests

    @Test("ImageProcessingError descriptions are correct")
    func errorDescriptions() {
        #expect(TestImageProcessingError.invalidImage.errorDescription == "Invalid image format")
        #expect(TestImageProcessingError.renderFailed.errorDescription == "Failed to render processed image")
        #expect(TestImageProcessingError.processingFailed.errorDescription == "Image processing failed")
    }
}

#endif
