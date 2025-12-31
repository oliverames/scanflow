//
//  PDFExporter.swift
//  ScanFlow
//
//  Multi-page PDF export functionality
//

import Foundation
#if os(macOS)
import AppKit
import PDFKit
#endif

#if os(macOS)

/// Utility for exporting scanned files to multi-page PDF documents
class PDFExporter {

    /// Export multiple scanned files to a single multi-page PDF
    static func export(files: [ScannedFile], to destinationURL: URL) async throws {
        guard !files.isEmpty else {
            throw PDFExportError.noFiles
        }

        let pdfDocument = PDFDocument()

        for (index, file) in files.enumerated() {
            guard let image = NSImage(contentsOf: file.fileURL) else {
                throw PDFExportError.invalidImage(file.filename)
            }

            // Create PDF page from image
            guard let pdfPage = createPDFPage(from: image) else {
                throw PDFExportError.pageCreationFailed(file.filename)
            }

            pdfDocument.insert(pdfPage, at: index)
        }

        // Add metadata
        addMetadata(to: pdfDocument, fileCount: files.count)

        // Write to disk
        guard pdfDocument.write(to: destinationURL) else {
            throw PDFExportError.writeFailed
        }
    }

    /// Create a PDF page from an NSImage
    private static func createPDFPage(from image: NSImage) -> PDFPage? {
        // Convert NSImage to PDF data
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pdfData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) else {
            return nil
        }

        // Create temporary image for PDF page
        guard let pdfImage = NSImage(data: pdfData) else {
            return nil
        }

        // Create PDF page
        let page = PDFPage(image: pdfImage)

        return page
    }

    /// Add metadata to PDF document
    private static func addMetadata(to document: PDFDocument, fileCount: Int) {
        var attributes = document.documentAttributes ?? [:]

        attributes[PDFDocumentAttribute.creatorAttribute] = "ScanFlow"
        attributes[PDFDocumentAttribute.producerAttribute] = "ScanFlow Scanner App"
        attributes[PDFDocumentAttribute.creationDateAttribute] = Date()
        attributes[PDFDocumentAttribute.titleAttribute] = "Scanned Documents (\(fileCount) pages)"

        document.documentAttributes = attributes
    }

    /// Export with OCR text layer (if OCR data available)
    static func exportWithOCR(files: [ScannedFile], to destinationURL: URL, imageProcessor: ImageProcessor) async throws {
        guard !files.isEmpty else {
            throw PDFExportError.noFiles
        }

        let pdfDocument = PDFDocument()

        for (index, file) in files.enumerated() {
            guard let image = NSImage(contentsOf: file.fileURL) else {
                throw PDFExportError.invalidImage(file.filename)
            }

            // Perform OCR
            let text = try await imageProcessor.recognizeText(image)

            // Create PDF page with text overlay
            guard let pdfPage = createPDFPage(from: image) else {
                throw PDFExportError.pageCreationFailed(file.filename)
            }

            // Add invisible text layer for searchable PDF
            if !text.isEmpty {
                addTextAnnotation(to: pdfPage, text: text)
            }

            pdfDocument.insert(pdfPage, at: index)
        }

        // Add metadata
        addMetadata(to: pdfDocument, fileCount: files.count)

        // Write to disk
        guard pdfDocument.write(to: destinationURL) else {
            throw PDFExportError.writeFailed
        }
    }

    // MARK: - PDF Append Mode

    /// Append new pages to an existing PDF document
    static func appendPages(files: [ScannedFile], to existingPDFURL: URL) async throws {
        guard !files.isEmpty else {
            throw PDFExportError.noFiles
        }

        // Load existing PDF
        guard let existingPDF = PDFDocument(url: existingPDFURL) else {
            throw PDFExportError.cannotOpenExistingPDF
        }

        let startingPageCount = existingPDF.pageCount

        // Add new pages
        for file in files {
            guard let image = NSImage(contentsOf: file.fileURL) else {
                throw PDFExportError.invalidImage(file.filename)
            }

            guard let pdfPage = createPDFPage(from: image) else {
                throw PDFExportError.pageCreationFailed(file.filename)
            }

            existingPDF.insert(pdfPage, at: existingPDF.pageCount)
        }

        // Update metadata to reflect new page count
        updateMetadataForAppend(to: existingPDF, newPageCount: existingPDF.pageCount - startingPageCount)

        // Write back to same location (atomic operation)
        guard existingPDF.write(to: existingPDFURL) else {
            throw PDFExportError.writeFailed
        }
    }

    /// Append pages with OCR to existing PDF
    static func appendPagesWithOCR(files: [ScannedFile], to existingPDFURL: URL, imageProcessor: ImageProcessor) async throws {
        guard !files.isEmpty else {
            throw PDFExportError.noFiles
        }

        // Load existing PDF
        guard let existingPDF = PDFDocument(url: existingPDFURL) else {
            throw PDFExportError.cannotOpenExistingPDF
        }

        let startingPageCount = existingPDF.pageCount

        // Add new pages with OCR
        for file in files {
            guard let image = NSImage(contentsOf: file.fileURL) else {
                throw PDFExportError.invalidImage(file.filename)
            }

            // Perform OCR
            let text = try await imageProcessor.recognizeText(image)

            guard let pdfPage = createPDFPage(from: image) else {
                throw PDFExportError.pageCreationFailed(file.filename)
            }

            // Add OCR text layer
            if !text.isEmpty {
                addTextAnnotation(to: pdfPage, text: text)
            }

            existingPDF.insert(pdfPage, at: existingPDF.pageCount)
        }

        // Update metadata
        updateMetadataForAppend(to: existingPDF, newPageCount: existingPDF.pageCount - startingPageCount)

        // Write back
        guard existingPDF.write(to: existingPDFURL) else {
            throw PDFExportError.writeFailed
        }
    }

    /// Insert pages at specific position in existing PDF
    static func insertPages(files: [ScannedFile], into existingPDFURL: URL, at position: Int) async throws {
        guard !files.isEmpty else {
            throw PDFExportError.noFiles
        }

        guard let existingPDF = PDFDocument(url: existingPDFURL) else {
            throw PDFExportError.cannotOpenExistingPDF
        }

        let insertPosition = min(position, existingPDF.pageCount)

        // Insert new pages at specified position
        for (offset, file) in files.enumerated() {
            guard let image = NSImage(contentsOf: file.fileURL) else {
                throw PDFExportError.invalidImage(file.filename)
            }

            guard let pdfPage = createPDFPage(from: image) else {
                throw PDFExportError.pageCreationFailed(file.filename)
            }

            existingPDF.insert(pdfPage, at: insertPosition + offset)
        }

        // Update metadata
        updateMetadataForAppend(to: existingPDF, newPageCount: files.count)

        // Write back
        guard existingPDF.write(to: existingPDFURL) else {
            throw PDFExportError.writeFailed
        }
    }

    /// Update PDF metadata after appending pages
    private static func updateMetadataForAppend(to document: PDFDocument, newPageCount: Int) {
        var attributes = document.documentAttributes ?? [:]

        attributes[PDFDocumentAttribute.modificationDateAttribute] = Date()

        if let currentTitle = attributes[PDFDocumentAttribute.titleAttribute] as? String {
            attributes[PDFDocumentAttribute.titleAttribute] = "\(currentTitle) (Updated: +\(newPageCount) pages)"
        }

        document.documentAttributes = attributes
    }

    /// Add text annotation to PDF page for searchability
    private static func addTextAnnotation(to page: PDFPage, text: String) {
        let bounds = page.bounds(for: .mediaBox)
        let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
        annotation.contents = text
        annotation.color = .clear
        annotation.font = NSFont.systemFont(ofSize: 12)
        page.addAnnotation(annotation)
    }
}

// MARK: - Errors

enum PDFExportError: LocalizedError {
    case noFiles
    case invalidImage(String)
    case pageCreationFailed(String)
    case writeFailed
    case cannotOpenExistingPDF

    var errorDescription: String? {
        switch self {
        case .noFiles:
            return "No files selected for export"
        case .invalidImage(let filename):
            return "Failed to load image: \(filename)"
        case .pageCreationFailed(let filename):
            return "Failed to create PDF page for: \(filename)"
        case .writeFailed:
            return "Failed to write PDF file"
        case .cannotOpenExistingPDF:
            return "Cannot open existing PDF for appending"
        }
    }
}

#endif
