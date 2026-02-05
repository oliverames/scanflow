//
//  DocumentSeparator.swift
//  ScanFlow
//
//  Intelligent document separation for batch scans
//  Detects document boundaries using blank pages, barcodes, and content analysis
//

import Foundation
#if os(macOS)
import AppKit
import Vision

/// Settings for document separation
struct SeparationSettings: Codable, Equatable {
    var enabled: Bool = false
    
    // Blank page detection
    var useBlankPages: Bool = true
    var blankSensitivity: Double = 0.5  // 0-1, higher = more sensitive
    var deleteBlankPages: Bool = true
    
    // Barcode-based separation
    var useBarcodes: Bool = false
    var barcodePattern: String = ".*"  // Regex pattern to match separator barcodes
    
    // Content analysis
    var useContentAnalysis: Bool = false
    var similarityThreshold: Double = 0.3  // 0-1, lower = more likely to split
    
    // Constraints
    var minimumPagesPerDocument: Int = 1
    
    // Advanced option
    var allowManualAdjustment: Bool = false
    
    static let `default` = SeparationSettings()
}

/// Document separator for intelligently splitting batch scans
@MainActor
class DocumentSeparator {
    private let imageProcessor: ImageProcessor
    private let barcodeRecognizer: BarcodeRecognizer
    
    /// Result of document separation
    struct SeparationResult {
        let documents: [[NSImage]]
        let boundaries: [DocumentBoundary]
        let removedBlankPages: [Int]
    }
    
    /// Information about a document boundary
    struct DocumentBoundary: Identifiable {
        let id = UUID()
        let afterPageIndex: Int
        let reason: BoundaryReason
        let confidence: Double
    }
    
    /// Reason for document boundary
    enum BoundaryReason: Equatable {
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
    
    init(imageProcessor: ImageProcessor, barcodeRecognizer: BarcodeRecognizer) {
        self.imageProcessor = imageProcessor
        self.barcodeRecognizer = barcodeRecognizer
    }
    
    /// Convenience initializer
    convenience init() {
        self.init(imageProcessor: ImageProcessor(), barcodeRecognizer: BarcodeRecognizer())
    }
    
    // MARK: - Public API
    
    /// Separate a batch of scanned pages into individual documents
    func separateDocuments(
        pages: [NSImage],
        settings: SeparationSettings
    ) async throws -> SeparationResult {
        guard settings.enabled else {
            // If separation is disabled, return all pages as single document
            return SeparationResult(documents: [pages], boundaries: [], removedBlankPages: [])
        }
        
        guard pages.count > 1 else {
            // Single page, no separation needed
            return SeparationResult(documents: [pages], boundaries: [], removedBlankPages: [])
        }
        
        var boundaries: [DocumentBoundary] = []
        var blankPageIndices: [Int] = []
        
        // Analyze each page transition
        for i in 0..<pages.count {
            // Check for blank page
            if settings.useBlankPages {
                let threshold = max(0.78, 0.98 - (settings.blankSensitivity * 0.20))
                let isBlank = await imageProcessor.isBlankPage(pages[i], threshold: threshold)
                
                if isBlank {
                    blankPageIndices.append(i)
                    
                    // Blank page creates boundary after itself (if not last page)
                    if i < pages.count - 1 {
                        boundaries.append(DocumentBoundary(
                            afterPageIndex: i,
                            reason: .blankPage,
                            confidence: 1.0
                        ))
                    }
                    continue
                }
            }
            
            // Check for barcode separator
            if settings.useBarcodes {
                if let boundary = try await checkBarcodeMarker(
                    page: pages[i],
                    pageIndex: i,
                    pattern: settings.barcodePattern
                ) {
                    boundaries.append(boundary)
                    continue
                }
            }
            
            // Check content similarity with next page
            if settings.useContentAnalysis && i < pages.count - 1 {
                // Skip if current page is blank
                if !blankPageIndices.contains(i) {
                    let similarity = try await comparePageContent(pages[i], pages[i + 1])
                    
                    if similarity < settings.similarityThreshold {
                        boundaries.append(DocumentBoundary(
                            afterPageIndex: i,
                            reason: .contentDissimilarity,
                            confidence: 1.0 - similarity
                        ))
                    }
                }
            }
        }
        
        // Remove duplicate boundaries at the same position (keep highest confidence)
        let consolidatedBoundaries = consolidateBoundaries(boundaries)
        
        // Group pages into documents
        let documents = groupPages(
            pages,
            boundaries: consolidatedBoundaries,
            blankPageIndices: settings.deleteBlankPages ? blankPageIndices : [],
            minimumPages: settings.minimumPagesPerDocument
        )
        
        return SeparationResult(
            documents: documents,
            boundaries: consolidatedBoundaries,
            removedBlankPages: settings.deleteBlankPages ? blankPageIndices : []
        )
    }
    
    /// Add a manual boundary at specified page index
    func addManualBoundary(
        to result: SeparationResult,
        afterPageIndex: Int,
        pages: [NSImage]
    ) -> SeparationResult {
        var newBoundaries = result.boundaries
        
        // Check if boundary already exists
        if !newBoundaries.contains(where: { $0.afterPageIndex == afterPageIndex }) {
            newBoundaries.append(DocumentBoundary(
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
        
        return SeparationResult(
            documents: documents,
            boundaries: newBoundaries,
            removedBlankPages: result.removedBlankPages
        )
    }
    
    /// Remove a boundary at specified page index
    func removeBoundary(
        from result: SeparationResult,
        afterPageIndex: Int,
        pages: [NSImage]
    ) -> SeparationResult {
        let newBoundaries = result.boundaries.filter { $0.afterPageIndex != afterPageIndex }
        
        let documents = groupPages(
            pages,
            boundaries: newBoundaries,
            blankPageIndices: result.removedBlankPages,
            minimumPages: 1
        )
        
        return SeparationResult(
            documents: documents,
            boundaries: newBoundaries,
            removedBlankPages: result.removedBlankPages
        )
    }
    
    // MARK: - Private Methods
    
    /// Check if page contains a barcode that matches the separator pattern
    private func checkBarcodeMarker(
        page: NSImage,
        pageIndex: Int,
        pattern: String
    ) async throws -> DocumentBoundary? {
        let barcodes = try await barcodeRecognizer.detectBarcodes(in: page)
        
        guard !barcodes.isEmpty else { return nil }
        
        // Check if any barcode matches the pattern
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        
        for barcode in barcodes {
            let range = NSRange(barcode.payload.startIndex..., in: barcode.payload)
            
            if let regex = regex,
               regex.firstMatch(in: barcode.payload, options: [], range: range) != nil {
                return DocumentBoundary(
                    afterPageIndex: pageIndex,
                    reason: .barcodeMarker(payload: barcode.payload),
                    confidence: Double(barcode.confidence)
                )
            }
        }
        
        return nil
    }
    
    /// Compare content similarity between two pages using OCR text
    private func comparePageContent(_ page1: NSImage, _ page2: NSImage) async throws -> Double {
        async let text1Task = imageProcessor.recognizeText(page1)
        async let text2Task = imageProcessor.recognizeText(page2)
        
        let text1 = try await text1Task
        let text2 = try await text2Task
        
        // If both pages have very little text, consider them similar (likely same document)
        if text1.count < 50 && text2.count < 50 {
            return 0.8
        }
        
        // Calculate cosine similarity of word frequencies
        return cosineSimilarity(text1, text2)
    }
    
    /// Calculate cosine similarity between two text strings
    private func cosineSimilarity(_ text1: String, _ text2: String) -> Double {
        let words1 = extractWords(from: text1)
        let words2 = extractWords(from: text2)
        
        guard !words1.isEmpty && !words2.isEmpty else {
            return 0.0
        }
        
        // Build word frequency vectors
        var allWords = Set<String>()
        allWords.formUnion(words1.keys)
        allWords.formUnion(words2.keys)
        
        var dotProduct: Double = 0
        var magnitude1: Double = 0
        var magnitude2: Double = 0
        
        for word in allWords {
            let freq1 = Double(words1[word] ?? 0)
            let freq2 = Double(words2[word] ?? 0)
            
            dotProduct += freq1 * freq2
            magnitude1 += freq1 * freq1
            magnitude2 += freq2 * freq2
        }
        
        let magnitude = sqrt(magnitude1) * sqrt(magnitude2)
        
        guard magnitude > 0 else { return 0.0 }
        
        return dotProduct / magnitude
    }
    
    /// Extract word frequencies from text
    private func extractWords(from text: String) -> [String: Int] {
        let lowercased = text.lowercased()
        let words = lowercased.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 }  // Ignore very short words
        
        var frequencies: [String: Int] = [:]
        for word in words {
            frequencies[word, default: 0] += 1
        }
        
        return frequencies
    }
    
    /// Consolidate boundaries at same position, keeping highest confidence
    private func consolidateBoundaries(_ boundaries: [DocumentBoundary]) -> [DocumentBoundary] {
        var bestByPosition: [Int: DocumentBoundary] = [:]
        
        for boundary in boundaries {
            if let existing = bestByPosition[boundary.afterPageIndex] {
                if boundary.confidence > existing.confidence {
                    bestByPosition[boundary.afterPageIndex] = boundary
                }
            } else {
                bestByPosition[boundary.afterPageIndex] = boundary
            }
        }
        
        return bestByPosition.values.sorted { $0.afterPageIndex < $1.afterPageIndex }
    }
    
    /// Group pages into documents based on boundaries
    private func groupPages(
        _ pages: [NSImage],
        boundaries: [DocumentBoundary],
        blankPageIndices: [Int],
        minimumPages: Int
    ) -> [[NSImage]] {
        var documents: [[NSImage]] = []
        var currentDocument: [NSImage] = []
        
        let boundaryIndices = Set(boundaries.map { $0.afterPageIndex })
        let blankIndices = Set(blankPageIndices)
        
        for (index, page) in pages.enumerated() {
            // Skip blank pages if they should be removed
            if blankIndices.contains(index) {
                continue
            }
            
            currentDocument.append(page)
            
            // Check if this is a boundary point
            if boundaryIndices.contains(index) && index < pages.count - 1 {
                // Ensure minimum pages requirement
                if currentDocument.count >= minimumPages {
                    documents.append(currentDocument)
                    currentDocument = []
                }
            }
        }
        
        // Add remaining pages as final document
        if !currentDocument.isEmpty {
            // If we have previous documents and current is too small, merge with last
            if currentDocument.count < minimumPages && !documents.isEmpty {
                documents[documents.count - 1].append(contentsOf: currentDocument)
            } else {
                documents.append(currentDocument)
            }
        }
        
        // Handle edge case: no documents created
        if documents.isEmpty && !pages.isEmpty {
            // Return non-blank pages as single document
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

// MARK: - Errors

enum DocumentSeparationError: LocalizedError {
    case invalidImage
    case processingFailed
    case noDocumentsCreated
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image for document separation"
        case .processingFailed:
            return "Document separation processing failed"
        case .noDocumentsCreated:
            return "No documents could be created from the scanned pages"
        }
    }
}

#endif
