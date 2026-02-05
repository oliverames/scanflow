//
//  ScanPreset.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

import Foundation

enum ScanFormat: String, Codable, CaseIterable {
    case pdf = "PDF"
    case compressedPDF = "Compressed PDF"
    case jpeg = "JPEG"
    case tiff = "TIFF"
    case png = "PNG"
}

enum DocumentType: String, Codable, CaseIterable {
    case photo = "Photo"
    case document = "Document"
}

enum ColorMode: String, Codable, CaseIterable {
    case color = "Color"
    case grayscale = "Grayscale"
    case blackWhite = "B&W"
}

enum ScanPaperSize: String, Codable, CaseIterable {
    case auto = "Auto"
    case letter = "US Letter"
    case legal = "US Legal"
    case a4 = "A4"
    case a5 = "A5"
    case custom = "Custom"
}

enum ScanSource: String, Codable, CaseIterable {
    case flatbed = "Flatbed"
    case adfFront = "ADF Front"
    case adfDuplex = "ADF Duplex"
}

enum BlankPageHandling: String, Codable, CaseIterable {
    case keep = "Keep"
    case delete = "Delete"
    case askUser = "Ask"
}

enum MediaDetection: String, Codable, CaseIterable {
    case none = "None"
    case autoCrop = "Auto crop"
    case deskew = "De-skew"
    case autoCropAndDeskew = "Auto crop and de-skew"
}

enum RotationAngle: Int, Codable, CaseIterable {
    case none = 0
    case rotate90 = 90
    case rotate180 = 180
    case rotate270 = 270

    var displayName: String {
        switch self {
        case .none: return "0°"
        case .rotate90: return "90°"
        case .rotate180: return "180°"
        case .rotate270: return "270°"
        }
    }
}

enum ExistingFileBehavior: String, Codable, CaseIterable {
    case increaseSequence = "Increase sequence number"
    case overwrite = "Overwrite"
    case askUser = "Ask"
}

// ImageCaptureCore specific options
enum BitDepth: Int, Codable, CaseIterable {
    case eight = 8
    case sixteen = 16

    var displayName: String {
        switch self {
        case .eight: return "8-bit"
        case .sixteen: return "16-bit"
        }
    }
}

enum ScanDocumentType: String, Codable, CaseIterable {
    case standard = "Standard"
    case positive = "Positive (slides)"
    case negative = "Negative (film)"
}

enum PageOrientation: Int, Codable, CaseIterable {
    case normal = 0
    case rotated90 = 90
    case rotated180 = 180
    case rotated270 = 270

    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .rotated90: return "90° CW"
        case .rotated180: return "180°"
        case .rotated270: return "90° CCW"
        }
    }
}

enum MeasurementUnit: String, Codable, CaseIterable {
    case inches = "Inches"
    case centimeters = "Centimeters"
    case pixels = "Pixels"
}

struct ScanPreset: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String

    // Basic settings
    var resolution: Int // DPI
    var format: ScanFormat
    var quality: Double // 0-1 for JPEG compression
    var searchablePDF: Bool
    var colorMode: ColorMode
    var paperSize: ScanPaperSize
    var source: ScanSource
    var destination: String

    // Filing options
    var fileNamePrefix: String
    var useSequenceNumber: Bool
    var sequenceStartNumber: Int
    var uniqueDateTag: Bool
    var editEachFilename: Bool
    var existingFileBehavior: ExistingFileBehavior
    var splitOnPage: Bool
    var splitPageNumber: Int

    // Workflow options
    var showConfigBeforeScan: Bool
    var scanOnDocumentPlacement: Bool
    var askForMorePages: Bool
    var useTimer: Bool
    var timerSeconds: Double
    var showProgressIndicator: Bool
    var openWithApp: Bool
    var openWithAppPath: String
    var printAfterScan: Bool
    var keepPrintedFile: Bool

    // Document type (for processing)
    var documentType: DocumentType

    // Auto-enhancement options
    var autoRotate: Bool
    var deskew: Bool
    var autoCrop: Bool
    var restoreColor: Bool
    var removeRedEye: Bool

    // Blank page handling
    var blankPageHandling: BlankPageHandling
    var blankPageSensitivity: Double // 0-1

    // Image adjustments
    var brightness: Double // -1 to 1
    var contrast: Double // -1 to 1
    var gamma: Double // 0.5 to 3.0
    var hue: Double // -1 to 1
    var saturation: Double // -1 to 1
    var lightness: Double // -1 to 1

    // Media detection
    var mediaDetection: MediaDetection
    var rotationAngle: RotationAngle

    // ImageCaptureCore options
    var bitDepth: BitDepth
    var scanDocumentType: ScanDocumentType  // For film scanners
    var useCustomScanArea: Bool
    var scanAreaX: Double  // In current measurement unit
    var scanAreaY: Double
    var scanAreaWidth: Double
    var scanAreaHeight: Double
    var measurementUnit: MeasurementUnit
    var bwThreshold: Int  // 0-255 for B&W scanning
    var oddPageOrientation: PageOrientation
    var evenPageOrientation: PageOrientation
    var reverseFeederPageOrder: Bool
    var overviewResolution: Int  // For preview scans

    // Advanced options
    var descreen: Bool // Remove moiré patterns
    var sharpen: Bool
    var invertColors: Bool

    // Multi-page options
    var useDuplex: Bool
    var rotateEvenPages: Bool // Rotate every second page by 180°
    var splitBookPages: Bool
    
    // Document separation settings (for batch ADF scanning)
    var separationSettings: SeparationSettings
    
    // AI-assisted file naming settings
    var namingSettings: NamingSettings

    // Legacy compatibility
    var autoEnhance: Bool { colorMode == .color }
    var useADF: Bool { source != .flatbed }
    var detectBlankPages: Bool { blankPageHandling != .keep }
    var splitOnBarcode: Bool { separationSettings.useBarcodes }  // Integrated with DocumentSeparator

    init(
        id: UUID = UUID(),
        name: String,
        resolution: Int = 300,
        format: ScanFormat = .pdf,
        quality: Double = 0.85,
        searchablePDF: Bool = false,
        colorMode: ColorMode = .color,
        paperSize: ScanPaperSize = .auto,
        source: ScanSource = .flatbed,
        destination: String = "~/Documents",
        // Filing options
        fileNamePrefix: String = "Scan-",
        useSequenceNumber: Bool = true,
        sequenceStartNumber: Int = 1,
        uniqueDateTag: Bool = false,
        editEachFilename: Bool = false,
        existingFileBehavior: ExistingFileBehavior = .increaseSequence,
        splitOnPage: Bool = false,
        splitPageNumber: Int = 1,
        // Workflow options
        showConfigBeforeScan: Bool = false,
        scanOnDocumentPlacement: Bool = false,
        askForMorePages: Bool = false,
        useTimer: Bool = false,
        timerSeconds: Double = 1.5,
        showProgressIndicator: Bool = true,
        openWithApp: Bool = false,
        openWithAppPath: String = "/Applications/Preview.app",
        printAfterScan: Bool = false,
        keepPrintedFile: Bool = true,
        // Document type
        documentType: DocumentType = .document,
        autoRotate: Bool = true,
        deskew: Bool = true,
        autoCrop: Bool = true,
        restoreColor: Bool = false,
        removeRedEye: Bool = false,
        blankPageHandling: BlankPageHandling = .delete,
        blankPageSensitivity: Double = 0.5,
        brightness: Double = 0,
        contrast: Double = 0.1,
        gamma: Double = 2.2,
        hue: Double = 0,
        saturation: Double = 0,
        lightness: Double = 0,
        mediaDetection: MediaDetection = .autoCropAndDeskew,
        rotationAngle: RotationAngle = .none,
        // ImageCaptureCore options
        bitDepth: BitDepth = .eight,
        scanDocumentType: ScanDocumentType = .standard,
        useCustomScanArea: Bool = false,
        scanAreaX: Double = 0,
        scanAreaY: Double = 0,
        scanAreaWidth: Double = 8.5,
        scanAreaHeight: Double = 11,
        measurementUnit: MeasurementUnit = .inches,
        bwThreshold: Int = 128,
        oddPageOrientation: PageOrientation = .normal,
        evenPageOrientation: PageOrientation = .normal,
        reverseFeederPageOrder: Bool = false,
        overviewResolution: Int = 75,
        // Advanced options
        descreen: Bool = false,
        sharpen: Bool = false,
        invertColors: Bool = false,
        useDuplex: Bool = false,
        rotateEvenPages: Bool = false,
        splitBookPages: Bool = false,
        // Document separation
        separationSettings: SeparationSettings = .default,
        // AI naming
        namingSettings: NamingSettings = .default
    ) {
        self.id = id
        self.name = name
        self.resolution = resolution
        self.format = format
        self.quality = quality
        self.searchablePDF = searchablePDF
        self.colorMode = colorMode
        self.paperSize = paperSize
        self.source = source
        self.destination = destination
        // Filing options
        self.fileNamePrefix = fileNamePrefix
        self.useSequenceNumber = useSequenceNumber
        self.sequenceStartNumber = sequenceStartNumber
        self.uniqueDateTag = uniqueDateTag
        self.editEachFilename = editEachFilename
        self.existingFileBehavior = existingFileBehavior
        self.splitOnPage = splitOnPage
        self.splitPageNumber = splitPageNumber
        // Workflow options
        self.showConfigBeforeScan = showConfigBeforeScan
        self.scanOnDocumentPlacement = scanOnDocumentPlacement
        self.askForMorePages = askForMorePages
        self.useTimer = useTimer
        self.timerSeconds = timerSeconds
        self.showProgressIndicator = showProgressIndicator
        self.openWithApp = openWithApp
        self.openWithAppPath = openWithAppPath
        self.printAfterScan = printAfterScan
        self.keepPrintedFile = keepPrintedFile
        // Document type
        self.documentType = documentType
        self.autoRotate = autoRotate
        self.deskew = deskew
        self.autoCrop = autoCrop
        self.restoreColor = restoreColor
        self.removeRedEye = removeRedEye
        self.blankPageHandling = blankPageHandling
        self.blankPageSensitivity = blankPageSensitivity
        self.brightness = brightness
        self.contrast = contrast
        self.gamma = gamma
        self.hue = hue
        self.saturation = saturation
        self.lightness = lightness
        self.mediaDetection = mediaDetection
        self.rotationAngle = rotationAngle
        // ImageCaptureCore options
        self.bitDepth = bitDepth
        self.scanDocumentType = scanDocumentType
        self.useCustomScanArea = useCustomScanArea
        self.scanAreaX = scanAreaX
        self.scanAreaY = scanAreaY
        self.scanAreaWidth = scanAreaWidth
        self.scanAreaHeight = scanAreaHeight
        self.measurementUnit = measurementUnit
        self.bwThreshold = bwThreshold
        self.oddPageOrientation = oddPageOrientation
        self.evenPageOrientation = evenPageOrientation
        self.reverseFeederPageOrder = reverseFeederPageOrder
        self.overviewResolution = overviewResolution
        // Advanced options
        self.descreen = descreen
        self.sharpen = sharpen
        self.invertColors = invertColors
        self.useDuplex = useDuplex
        self.rotateEvenPages = rotateEvenPages
        self.splitBookPages = splitBookPages
        // Document separation
        self.separationSettings = separationSettings
        // AI naming
        self.namingSettings = namingSettings
    }

    static let defaults: [ScanPreset] = [
        // ExactScan-style presets
        ScanPreset(
            name: "Color PDF",
            resolution: 300,
            format: .pdf,
            colorMode: .color,
            source: .adfFront
        ),
        ScanPreset(
            name: "Searchable PDF",
            resolution: 300,
            format: .pdf,
            searchablePDF: true,
            colorMode: .color,
            source: .adfFront
        ),
        ScanPreset(
            name: "Gray PDF",
            resolution: 300,
            format: .pdf,
            colorMode: .grayscale,
            source: .adfFront
        ),
        ScanPreset(
            name: "B/W PDF",
            resolution: 300,
            format: .pdf,
            colorMode: .blackWhite,
            source: .adfFront
        ),
        ScanPreset(
            name: "Color Copy",
            resolution: 300,
            format: .jpeg,
            colorMode: .color,
            source: .flatbed
        ),
        ScanPreset(
            name: "Gray Copy",
            resolution: 300,
            format: .jpeg,
            colorMode: .grayscale,
            source: .flatbed
        ),
        ScanPreset(
            name: "B/W Copy",
            resolution: 300,
            format: .jpeg,
            colorMode: .blackWhite,
            source: .flatbed
        ),
        ScanPreset(
            name: "Photos",
            resolution: 600,
            format: .jpeg,
            quality: 0.95,
            colorMode: .color,
            source: .flatbed,
            documentType: .photo,
            restoreColor: true,
            removeRedEye: true
        ),
        ScanPreset(
            name: "Archive (600 DPI)",
            resolution: 600,
            format: .tiff,
            quality: 1.0,
            colorMode: .color,
            source: .adfFront
        )
    ]

    static let quickScan = defaults[0]
    static let searchablePDF = defaults.first { $0.searchablePDF } ?? defaults[0]
    static let archiveQuality = defaults[7]
}
