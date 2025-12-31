//
//  ScanPreset.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

import Foundation

enum ScanFormat: String, Codable, CaseIterable {
    case jpeg = "JPEG"
    case tiff = "TIFF"
    case png = "PNG"
}

enum DocumentType: String, Codable, CaseIterable {
    case photo = "Photo"
    case document = "Document"
    case polaroid = "Polaroid"
    case panoramic = "Panoramic"
}

struct ScanPreset: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var resolution: Int // DPI
    var format: ScanFormat
    var quality: Double // 0-1
    var autoEnhance: Bool
    var restoreColor: Bool
    var removeRedEye: Bool
    var autoRotate: Bool
    var deskew: Bool
    var destination: String // Path as string for Codable
    var documentType: DocumentType

    // Advanced scanning options
    var useDuplex: Bool = false        // Scan both sides
    var useADF: Bool = false           // Use automatic document feeder
    var detectBlankPages: Bool = true  // Skip blank pages
    var splitOnBarcode: Bool = false   // Split batch on barcode
    var applyImprinter: Bool = false   // Apply dynamic text overlay

    init(
        id: UUID = UUID(),
        name: String,
        resolution: Int = 300,
        format: ScanFormat = .jpeg,
        quality: Double = 0.95,
        autoEnhance: Bool = true,
        restoreColor: Bool = false,
        removeRedEye: Bool = false,
        autoRotate: Bool = true,
        deskew: Bool = true,
        destination: String = "~/Pictures/Scans",
        documentType: DocumentType = .photo
    ) {
        self.id = id
        self.name = name
        self.resolution = resolution
        self.format = format
        self.quality = quality
        self.autoEnhance = autoEnhance
        self.restoreColor = restoreColor
        self.removeRedEye = removeRedEye
        self.autoRotate = autoRotate
        self.deskew = deskew
        self.destination = destination
        self.documentType = documentType
    }

    static let defaults: [ScanPreset] = [
        // Professional document scanning presets matching spec
        ScanPreset(
            name: "Quick B&W (300 DPI)",
            resolution: 300,
            format: .jpeg,
            quality: 0.85,
            autoEnhance: true,
            deskew: true,
            documentType: .document
        ),
        ScanPreset(
            name: "Searchable PDF (300 DPI)",
            resolution: 300,
            format: .jpeg,  // Will be converted to PDF with OCR
            quality: 0.90,
            autoEnhance: true,
            deskew: true,
            documentType: .document
        ),
        ScanPreset(
            name: "Archive Quality (600 DPI)",
            resolution: 600,
            format: .tiff,
            quality: 1.0,
            autoEnhance: false,
            deskew: true,
            documentType: .document
        ),
        ScanPreset(
            name: "Color Document (300 DPI)",
            resolution: 300,
            format: .jpeg,
            quality: 0.92,
            autoEnhance: true,
            deskew: true,
            documentType: .document
        ),
        ScanPreset(
            name: "Receipt/Business Card",
            resolution: 300,
            format: .jpeg,
            quality: 0.88,
            autoEnhance: true,
            deskew: true,
            documentType: .photo  // Small document
        ),
        ScanPreset(
            name: "Legal Documents (600 DPI Searchable)",
            resolution: 600,
            format: .tiff,
            quality: 1.0,
            autoEnhance: true,
            deskew: true,
            documentType: .document
        ),
        ScanPreset(
            name: "Photo Scan (600 DPI)",
            resolution: 600,
            format: .jpeg,
            quality: 0.95,
            autoEnhance: true,
            restoreColor: true,
            removeRedEye: true,
            documentType: .photo
        ),
        ScanPreset(
            name: "Enlargement (1200 DPI)",
            resolution: 1200,
            format: .tiff,
            quality: 1.0,
            autoEnhance: false,
            documentType: .photo
        )
    ]

    static let quickScan = defaults[0]
    static let searchablePDF = defaults[1]
    static let archiveQuality = defaults[2]
}
