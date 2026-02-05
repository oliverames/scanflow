//
//  DocumentSeparatorTests.swift
//  ScanFlowTests
//
//  Unit tests for document separation logic
//  Note: These tests are self-contained and copy minimal types from the main target
//

import Testing
import Foundation
#if os(macOS)
import AppKit
import Vision
import CoreImage

// MARK: - Copied Types for Testing

/// Settings for document separation (copied from main target for testing)
private struct TestSeparationSettings {
    var enabled: Bool = false
    var useBlankPages: Bool = true
    var blankSensitivity: Double = 0.5
    var deleteBlankPages: Bool = true
    var useBarcodes: Bool = false
    var barcodePattern: String = ".*"
    var useContentAnalysis: Bool = false
    var similarityThreshold: Double = 0.3
    var minimumPagesPerDocument: Int = 1
    var allowManualAdjustment: Bool = false

    static let `default` = TestSeparationSettings()
}

/// Reason for document boundary
private enum TestBoundaryReason: Equatable {
    case blankPage
    case barcodeMarker(payload: String)
    case contentDissimilarity
    case userManual

    var description: String {
        switch self {
        case .blankPage:
            return "Blank page detected"
        case .barcodeMarker(let payload):
            return "Barcode separator: \(payload)"
        case .contentDissimilarity:
            return "Content change detected"
        case .userManual:
            return "Manual split"
        }
    }
}

/// Minimal ImageProcessor for blank page detection
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
}

/// Document boundary information
private struct TestDocumentBoundary {
    let id = UUID()
    let afterPageIndex: Int
    let reason: TestBoundaryReason
    let confidence: Double
}

/// Result of document separation
private struct TestSeparationResult {
    let documents: [[NSImage]]
    let boundaries: [TestDocumentBoundary]
    let removedBlankPages: [Int]
}

/// Minimal DocumentSeparator for testing
private class TestDocumentSeparator {
    private let imageProcessor = TestImageProcessor()

    func separateDocuments(pages: [NSImage], settings: TestSeparationSettings) async throws -> TestSeparationResult {
        guard settings.enabled else {
            return TestSeparationResult(documents: [pages], boundaries: [], removedBlankPages: [])
        }

        guard pages.count > 1 else {
            return TestSeparationResult(documents: [pages], boundaries: [], removedBlankPages: [])
        }

        var boundaries: [TestDocumentBoundary] = []
        var blankPageIndices: [Int] = []

        for i in 0..<pages.count {
            if settings.useBlankPages {
                let threshold = 1.0 - (settings.blankSensitivity * 0.1)
                let isBlank = await imageProcessor.isBlankPage(pages[i], threshold: threshold)

                if isBlank {
                    blankPageIndices.append(i)
                    if i < pages.count - 1 {
                        boundaries.append(TestDocumentBoundary(
                            afterPageIndex: i,
                            reason: .blankPage,
                            confidence: 1.0
                        ))
                    }
                }
            }
        }

        let documents = groupPages(
            pages,
            boundaries: boundaries,
            blankPageIndices: settings.deleteBlankPages ? blankPageIndices : [],
            minimumPages: settings.minimumPagesPerDocument
        )

        return TestSeparationResult(
            documents: documents,
            boundaries: boundaries,
            removedBlankPages: settings.deleteBlankPages ? blankPageIndices : []
        )
    }

    func addManualBoundary(to result: TestSeparationResult, afterPageIndex: Int, pages: [NSImage]) -> TestSeparationResult {
        var newBoundaries = result.boundaries

        if !newBoundaries.contains(where: { $0.afterPageIndex == afterPageIndex }) {
            newBoundaries.append(TestDocumentBoundary(
                afterPageIndex: afterPageIndex,
                reason: .userManual,
                confidence: 1.0
            ))
            newBoundaries.sort { $0.afterPageIndex < $1.afterPageIndex }
        }

        let documents = groupPages(
            pages,
            boundaries: newBoundaries,
            blankPageIndices: result.removedBlankPages,
            minimumPages: 1
        )

        return TestSeparationResult(
            documents: documents,
            boundaries: newBoundaries,
            removedBlankPages: result.removedBlankPages
        )
    }

    func removeBoundary(from result: TestSeparationResult, afterPageIndex: Int, pages: [NSImage]) -> TestSeparationResult {
        let newBoundaries = result.boundaries.filter { $0.afterPageIndex != afterPageIndex }

        let documents = groupPages(
            pages,
            boundaries: newBoundaries,
            blankPageIndices: result.removedBlankPages,
            minimumPages: 1
        )

        return TestSeparationResult(
            documents: documents,
            boundaries: newBoundaries,
            removedBlankPages: result.removedBlankPages
        )
    }

    private func groupPages(_ pages: [NSImage], boundaries: [TestDocumentBoundary], blankPageIndices: [Int], minimumPages: Int) -> [[NSImage]] {
        var documents: [[NSImage]] = []
        var currentDocument: [NSImage] = []

        let boundaryIndices = Set(boundaries.map { $0.afterPageIndex })
        let blankIndices = Set(blankPageIndices)

        for (index, page) in pages.enumerated() {
            if blankIndices.contains(index) {
                continue
            }

            currentDocument.append(page)

            if boundaryIndices.contains(index) && index < pages.count - 1 {
                if currentDocument.count >= minimumPages {
                    documents.append(currentDocument)
                    currentDocument = []
                }
            }
        }

        if !currentDocument.isEmpty {
            if currentDocument.count < minimumPages && !documents.isEmpty {
                documents[documents.count - 1].append(contentsOf: currentDocument)
            } else {
                documents.append(currentDocument)
            }
        }

        if documents.isEmpty && !pages.isEmpty {
            let nonBlankPages = pages.enumerated()
                .filter { !blankIndices.contains($0.offset) }
                .map { $0.element }

            if !nonBlankPages.isEmpty {
                documents.append(nonBlankPages)
            }
        }

        return documents
    }
}

// MARK: - Tests

@Suite("DocumentSeparator Tests")
struct DocumentSeparatorTests {

    // MARK: - Test Helpers

    private func createTestImage(brightness: CGFloat, size: NSSize = NSSize(width: 100, height: 100)) -> NSImage {
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor(white: brightness, alpha: 1.0).setFill()
        NSRect(origin: .zero, size: size).fill()
        image.unlockFocus()
        return image
    }

    // MARK: - Basic Separation Tests

    @Test("Disabled separation returns single document")
    @MainActor
    func disabledSeparationReturnsSingleDocument() async throws {
        let separator = TestDocumentSeparator()
        let pages = [createTestImage(brightness: 0.5), createTestImage(brightness: 0.5)]

        var settings = TestSeparationSettings.default
        settings.enabled = false

        let result = try await separator.separateDocuments(pages: pages, settings: settings)

        #expect(result.documents.count == 1)
        #expect(result.documents[0].count == 2)
        #expect(result.boundaries.isEmpty)
    }

    @Test("Single page returns single document")
    @MainActor
    func singlePageReturnsSingleDocument() async throws {
        let separator = TestDocumentSeparator()
        let pages = [createTestImage(brightness: 0.5)]

        var settings = TestSeparationSettings.default
        settings.enabled = true

        let result = try await separator.separateDocuments(pages: pages, settings: settings)

        #expect(result.documents.count == 1)
        #expect(result.documents[0].count == 1)
    }

    @Test("Empty pages returns empty result")
    @MainActor
    func emptyPagesReturnsEmptyResult() async throws {
        let separator = TestDocumentSeparator()
        let pages: [NSImage] = []

        var settings = TestSeparationSettings.default
        settings.enabled = true

        let result = try await separator.separateDocuments(pages: pages, settings: settings)

        #expect(result.documents.isEmpty || result.documents == [[]])
    }

    // MARK: - Blank Page Detection Tests

    @Test("Blank page creates document boundary")
    @MainActor
    func blankPageCreatesBoundary() async throws {
        let separator = TestDocumentSeparator()

        // Use fully white (1.0) for the blank page to ensure detection
        // Keep blank pages to verify the boundary is actually created
        let pages = [
            createTestImage(brightness: 0.5),
            createTestImage(brightness: 1.0),
            createTestImage(brightness: 0.5)
        ]

        var settings = TestSeparationSettings.default
        settings.enabled = true
        settings.useBlankPages = true
        settings.blankSensitivity = 0.5
        settings.deleteBlankPages = false  // Keep blanks to verify split

        let result = try await separator.separateDocuments(pages: pages, settings: settings)

        // Verify a boundary was detected at the blank page
        #expect(result.boundaries.count == 1)
        #expect(result.boundaries.first?.reason == .blankPage)
        #expect(result.boundaries.first?.afterPageIndex == 1)
    }

    @Test("Blank pages removed when deleteBlankPages is true")
    @MainActor
    func blankPagesRemovedWhenEnabled() async throws {
        let separator = TestDocumentSeparator()

        let pages = [
            createTestImage(brightness: 0.5),
            createTestImage(brightness: 1.0),
            createTestImage(brightness: 0.5)
        ]

        var settings = TestSeparationSettings.default
        settings.enabled = true
        settings.useBlankPages = true
        settings.blankSensitivity = 0.5
        settings.deleteBlankPages = true

        let result = try await separator.separateDocuments(pages: pages, settings: settings)

        let totalPages = result.documents.reduce(0) { $0 + $1.count }
        #expect(totalPages == 2)
        #expect(result.removedBlankPages.count == 1)
    }

    @Test("Blank pages kept when deleteBlankPages is false")
    @MainActor
    func blankPagesKeptWhenDisabled() async throws {
        let separator = TestDocumentSeparator()

        let pages = [
            createTestImage(brightness: 0.5),
            createTestImage(brightness: 1.0),
            createTestImage(brightness: 0.5)
        ]

        var settings = TestSeparationSettings.default
        settings.enabled = true
        settings.useBlankPages = true
        settings.blankSensitivity = 0.5
        settings.deleteBlankPages = false

        let result = try await separator.separateDocuments(pages: pages, settings: settings)

        let totalPages = result.documents.reduce(0) { $0 + $1.count }
        #expect(totalPages == 3)
        #expect(result.removedBlankPages.isEmpty)
    }

    // MARK: - Manual Boundary Tests

    @Test("Add manual boundary splits document")
    @MainActor
    func addManualBoundarySplitsDocument() async throws {
        let separator = TestDocumentSeparator()

        let pages = [
            createTestImage(brightness: 0.5),
            createTestImage(brightness: 0.5),
            createTestImage(brightness: 0.5)
        ]

        var settings = TestSeparationSettings.default
        settings.enabled = false

        let initialResult = try await separator.separateDocuments(pages: pages, settings: settings)
        #expect(initialResult.documents.count == 1)

        let updatedResult = separator.addManualBoundary(
            to: initialResult,
            afterPageIndex: 1,
            pages: pages
        )

        #expect(updatedResult.documents.count == 2)
        #expect(updatedResult.documents[0].count == 2)
        #expect(updatedResult.documents[1].count == 1)
    }

    @Test("Remove boundary merges documents")
    @MainActor
    func removeBoundaryMergesDocuments() async throws {
        let separator = TestDocumentSeparator()

        let pages = [
            createTestImage(brightness: 0.5),
            createTestImage(brightness: 0.5),
            createTestImage(brightness: 0.5)
        ]

        let initialResult = TestSeparationResult(
            documents: [[pages[0], pages[1]], [pages[2]]],
            boundaries: [TestDocumentBoundary(
                afterPageIndex: 1,
                reason: .userManual,
                confidence: 1.0
            )],
            removedBlankPages: []
        )

        let updatedResult = separator.removeBoundary(
            from: initialResult,
            afterPageIndex: 1,
            pages: pages
        )

        #expect(updatedResult.documents.count == 1)
        #expect(updatedResult.documents[0].count == 3)
        #expect(updatedResult.boundaries.isEmpty)
    }

    // MARK: - Boundary Reason Tests

    @Test("Boundary reason descriptions are correct")
    func boundaryReasonDescriptions() {
        let blankReason = TestBoundaryReason.blankPage
        #expect(blankReason.description == "Blank page detected")

        let barcodeReason = TestBoundaryReason.barcodeMarker(payload: "DOC-001")
        #expect(barcodeReason.description == "Barcode separator: DOC-001")

        let contentReason = TestBoundaryReason.contentDissimilarity
        #expect(contentReason.description == "Content change detected")

        let manualReason = TestBoundaryReason.userManual
        #expect(manualReason.description == "Manual split")
    }
}

#endif
