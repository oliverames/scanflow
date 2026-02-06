//
//  ScanPreset.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

import Foundation

public enum ScanFormat: String, Codable, CaseIterable {
    case pdf = "PDF"
    case compressedPDF = "Compressed PDF"
    case jpeg = "JPEG"
    case tiff = "TIFF"
    case png = "PNG"
}

public enum DocumentType: String, Codable, CaseIterable {
    case photo = "Photo"
    case document = "Document"
}

public enum ColorMode: String, Codable, CaseIterable {
    case color = "Color"
    case grayscale = "Grayscale"
    case blackWhite = "B&W"
}

public enum ScanPaperSize: String, Codable, CaseIterable {
    case auto = "Auto"
    case letter = "US Letter"
    case legal = "US Legal"
    case a4 = "A4"
    case a5 = "A5"
    case custom = "Custom"
}

public enum ScanSource: String, Codable, CaseIterable {
    case flatbed = "Flatbed"
    case adfFront = "ADF Front"
    case adfDuplex = "ADF Duplex"
}

public enum BlankPageHandling: String, Codable, CaseIterable {
    case keep = "Keep"
    case delete = "Delete"
    case askUser = "Ask"
}

public enum MediaDetection: String, Codable, CaseIterable {
    case none = "None"
    case autoCrop = "Auto crop"
    case deskew = "De-skew"
    case autoCropAndDeskew = "Auto crop and de-skew"
}

public enum RotationAngle: Int, Codable, CaseIterable {
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

public enum ExistingFileBehavior: String, Codable, CaseIterable {
    case increaseSequence = "Increase sequence number"
    case overwrite = "Overwrite"
    case askUser = "Ask"
}

// ImageCaptureCore specific options
public enum BitDepth: Int, Codable, CaseIterable {
    case eight = 8
    case sixteen = 16

    var displayName: String {
        switch self {
        case .eight: return "8-bit"
        case .sixteen: return "16-bit"
        }
    }
}

public enum ScanDocumentType: String, Codable, CaseIterable {
    case standard = "Standard"
    case positive = "Positive (slides)"
    case negative = "Negative (film)"
}

public enum PageOrientation: Int, Codable, CaseIterable {
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

public enum MeasurementUnit: String, Codable, CaseIterable {
    case inches = "Inches"
    case centimeters = "Centimeters"
    case pixels = "Pixels"
}

public struct ScanPreset: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String

    // Basic settings
    public var resolution: Int // DPI
    public var format: ScanFormat
    public var quality: Double // 0-1 for JPEG compression
    public var searchablePDF: Bool
    public var colorMode: ColorMode
    public var paperSize: ScanPaperSize
    public var source: ScanSource
    public var destination: String

    // Filing options
    public var fileNamePrefix: String
    public var useSequenceNumber: Bool
    public var sequenceStartNumber: Int
    public var uniqueDateTag: Bool
    public var editEachFilename: Bool
    public var existingFileBehavior: ExistingFileBehavior
    public var splitOnPage: Bool
    public var splitPageNumber: Int

    // Workflow options
    public var showConfigBeforeScan: Bool
    public var scanOnDocumentPlacement: Bool
    public var askForMorePages: Bool
    public var useTimer: Bool
    public var timerSeconds: Double
    public var showProgressIndicator: Bool
    public var openWithApp: Bool
    public var openWithAppPath: String
    public var printAfterScan: Bool
    public var keepPrintedFile: Bool

    // Document type (for processing)
    public var documentType: DocumentType

    // Auto-enhancement options
    public var autoRotate: Bool
    public var deskew: Bool
    public var autoCrop: Bool
    public var restoreColor: Bool
    public var removeRedEye: Bool

    // Blank page handling
    public var blankPageHandling: BlankPageHandling
    public var blankPageSensitivity: Double // 0-1

    // Image adjustments
    public var brightness: Double // -1 to 1
    public var contrast: Double // -1 to 1
    public var gamma: Double // 0.5 to 3.0
    public var hue: Double // -1 to 1
    public var saturation: Double // -1 to 1
    public var lightness: Double // -1 to 1

    // Media detection
    public var mediaDetection: MediaDetection
    public var rotationAngle: RotationAngle

    // ImageCaptureCore options
    public var bitDepth: BitDepth
    public var scanDocumentType: ScanDocumentType  // For film scanners
    public var useCustomScanArea: Bool
    public var scanAreaX: Double  // In current measurement unit
    public var scanAreaY: Double
    public var scanAreaWidth: Double
    public var scanAreaHeight: Double
    public var measurementUnit: MeasurementUnit
    public var bwThreshold: Int  // 0-255 for B&W scanning
    public var oddPageOrientation: PageOrientation
    public var evenPageOrientation: PageOrientation
    public var reverseFeederPageOrder: Bool
    public var overviewResolution: Int  // For preview scans

    // Advanced options
    public var descreen: Bool // Remove moiré patterns
    public var sharpen: Bool
    public var invertColors: Bool

    // Multi-page options
    public var useDuplex: Bool
    public var rotateEvenPages: Bool // Rotate every second page by 180°
    public var splitBookPages: Bool

    // Document separation settings (for batch ADF scanning)
    public var separationSettings: SeparationSettings

    // AI-assisted file naming settings
    public var namingSettings: NamingSettings

    // Legacy compatibility
    public var autoEnhance: Bool { colorMode == .color }
    public var useADF: Bool { source != .flatbed }
    public var detectBlankPages: Bool { blankPageHandling != .keep }
    public var splitOnBarcode: Bool { separationSettings.useBarcodes }  // Integrated with DocumentSeparator

    public init(
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

    public static let defaults: [ScanPreset] = [
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

    public static let quickScan = defaults[0]
    public static let searchablePDF = defaults.first { $0.searchablePDF } ?? defaults[0]
    public static let archiveQuality = defaults[7]
}
