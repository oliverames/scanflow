//
//  AppState.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

import Foundation
import SwiftUI
import os.log
#if os(macOS)
import PDFKit
#endif

private let logger = Logger(subsystem: "com.scanflow.app", category: "AppState")

enum NavigationSection: String, CaseIterable, Identifiable {
    case scan = "Scan"
    case queue = "Scan Queue"
    case library = "Scanned Files"
    case presets = "Scan Presets"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .scan: return "scanner"
        case .queue: return "list.bullet"
        case .library: return "photo.stack"
        case .presets: return "slider.horizontal.3"
        }
    }
}

@MainActor
@Observable
class AppState {
    var scannerManager = ScannerManager()
    #if os(macOS)
    var imageProcessor = ImageProcessor()
    #endif
    var scanQueue: [QueuedScan] = []
    var scannedFiles: [ScannedFile] = []
    var presets: [ScanPreset] = ScanPreset.defaults
    var currentPreset: ScanPreset = ScanPreset.quickScan
    var selectedSection: NavigationSection = .scan
    var isScanning: Bool = false
    var showingAlert: Bool = false
    var alertMessage: String = ""
    var showScanSettings: Bool = true
    var showScannerSelection: Bool = false

    // Settings - use separate ObservableObject to avoid @Observable/@AppStorage conflict
    @ObservationIgnored private var _settings = SettingsStore()
    
    var defaultResolution: Int {
        get { _settings.defaultResolution }
        set { _settings.defaultResolution = newValue }
    }
    var defaultFormat: String {
        get { _settings.defaultFormat }
        set { _settings.defaultFormat = newValue }
    }
    var scanDestination: String {
        get { _settings.scanDestination }
        set { _settings.scanDestination = newValue }
    }
    var autoOpenDestination: Bool {
        get { _settings.autoOpenDestination }
        set { _settings.autoOpenDestination = newValue }
    }
    var organizationPattern: String {
        get { _settings.organizationPattern }
        set { _settings.organizationPattern = newValue }
    }
    var fileNamingTemplate: String {
        get { _settings.fileNamingTemplate }
        set { _settings.fileNamingTemplate = newValue }
    }
    var useMockScanner: Bool {
        get { _settings.useMockScanner }
        set { _settings.useMockScanner = newValue }
    }

    // AI-assisted file naming settings (defaults for new presets)
    var defaultNamingSettings: NamingSettings {
        get { _settings.defaultNamingSettings }
        set { _settings.defaultNamingSettings = newValue }
    }

    // Document separation settings (defaults for new presets)
    var defaultSeparationSettings: SeparationSettings {
        get { _settings.defaultSeparationSettings }
        set { _settings.defaultSeparationSettings = newValue }
    }

    init() {
        logger.info("AppState initializing...")
        loadPresets()
        logger.info("AppState initialized with \(self.presets.count) presets")
    }

    func loadPresets() {
        logger.info("Loading presets from UserDefaults")
        if let data = UserDefaults.standard.data(forKey: "customPresets"),
           let customPresets = try? JSONDecoder().decode([ScanPreset].self, from: data) {
            presets = ScanPreset.defaults + customPresets
            logger.info("Loaded \(customPresets.count) custom presets")
        } else {
            logger.info("No custom presets found, using defaults")
        }
    }

    func savePresets() {
        let customPresets = presets.filter { preset in
            !ScanPreset.defaults.contains { $0.id == preset.id }
        }
        if let data = try? JSONEncoder().encode(customPresets) {
            UserDefaults.standard.set(data, forKey: "customPresets")
            logger.info("Saved \(customPresets.count) custom presets")
        }
    }

    func addToQueue(preset: ScanPreset, count: Int = 1) {
        logger.info("Adding \(count) scan(s) to queue with preset: \(preset.name)")
        for i in 0..<count {
            let scan = QueuedScan(
                name: "Scan \(scanQueue.count + i + 1)",
                preset: preset
            )
            scanQueue.append(scan)
        }
        logger.info("Queue now contains \(self.scanQueue.count) items")
    }

    func removeFromQueue(scan: QueuedScan) {
        logger.info("Removing scan from queue: \(scan.name)")
        scanQueue.removeAll { $0.id == scan.id }
    }

    func startScanning() async {
        guard !scanQueue.isEmpty else {
            logger.warning("startScanning called but queue is empty")
            return
        }

        logger.info("Starting scan process with \(self.scanQueue.count) items in queue")
        isScanning = true

        for index in scanQueue.indices where scanQueue[index].status == .pending {
            logger.info("Processing queue item \(index + 1): \(self.scanQueue[index].name)")
            scanQueue[index].status = .scanning

            do {
                #if os(macOS)
                logger.info("Initiating scan with preset: \(self.scanQueue[index].preset.name)")
                let result = try await scannerManager.scan(with: scanQueue[index].preset)
                logger.info("Scan completed, processing image...")

                scanQueue[index].status = .processing
                let savedFile = try await saveScannedImage(result, preset: scanQueue[index].preset)
                scannedFiles.append(savedFile)
                logger.info("Image saved to: \(savedFile.fileURL.path)")

                scanQueue[index].status = .completed
                logger.info("Scan \(index + 1) completed successfully")
                #endif
            } catch {
                logger.error("Scan failed: \(error.localizedDescription)")
                scanQueue[index].status = .failed(error.localizedDescription)
                showAlert(message: "Scan failed: \(error.localizedDescription)")
            }
        }

        isScanning = false
        logger.info("Scan process completed")
    }

    #if os(macOS)
    private func saveScannedImage(_ result: ScanResult, preset: ScanPreset) async throws -> ScannedFile {
        // Expand tilde in path
        let destPath = NSString(string: preset.destination).expandingTildeInPath
        let destURL = URL(fileURLWithPath: destPath)

        // Create directory if needed
        try? FileManager.default.createDirectory(at: destURL, withIntermediateDirectories: true)

        // Generate filename
        let filename = generateFilename(format: preset.format)
        let fileURL = destURL.appendingPathComponent(filename)

        let images = result.images
        let pageCount = images.count
        logger.info("Saving \(pageCount) page(s) to \(fileURL.path)")

        // Handle different formats
        switch preset.format {
        case .jpeg:
            // For JPEG, save only the first page (or create multiple files for multi-page)
            if pageCount > 1 {
                // Save each page as a separate JPEG with sequence number
                for (index, image) in images.enumerated() {
                    guard let tiffData = image.tiffRepresentation,
                          let bitmapImage = NSBitmapImageRep(data: tiffData),
                          let imageData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: preset.quality]) else {
                        throw ScannerError.scanFailed
                    }
                    let pageFilename = filename.replacingOccurrences(of: ".jpeg", with: "_\(String(format: "%03d", index + 1)).jpeg")
                    let pageURL = destURL.appendingPathComponent(pageFilename)
                    try imageData.write(to: pageURL)
                }
            } else {
                guard let tiffData = result.image.tiffRepresentation,
                      let bitmapImage = NSBitmapImageRep(data: tiffData),
                      let imageData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: preset.quality]) else {
                    throw ScannerError.scanFailed
                }
                try imageData.write(to: fileURL)
            }

        case .png:
            // For PNG, save only the first page (or create multiple files for multi-page)
            if pageCount > 1 {
                for (index, image) in images.enumerated() {
                    guard let tiffData = image.tiffRepresentation,
                          let bitmapImage = NSBitmapImageRep(data: tiffData),
                          let imageData = bitmapImage.representation(using: .png, properties: [:]) else {
                        throw ScannerError.scanFailed
                    }
                    let pageFilename = filename.replacingOccurrences(of: ".png", with: "_\(String(format: "%03d", index + 1)).png")
                    let pageURL = destURL.appendingPathComponent(pageFilename)
                    try imageData.write(to: pageURL)
                }
            } else {
                guard let tiffData = result.image.tiffRepresentation,
                      let bitmapImage = NSBitmapImageRep(data: tiffData),
                      let imageData = bitmapImage.representation(using: .png, properties: [:]) else {
                    throw ScannerError.scanFailed
                }
                try imageData.write(to: fileURL)
            }

        case .tiff:
            // For TIFF, save only the first page (or create multiple files for multi-page)
            if pageCount > 1 {
                for (index, image) in images.enumerated() {
                    guard let tiffData = image.tiffRepresentation else {
                        throw ScannerError.scanFailed
                    }
                    let pageFilename = filename.replacingOccurrences(of: ".tiff", with: "_\(String(format: "%03d", index + 1)).tiff")
                    let pageURL = destURL.appendingPathComponent(pageFilename)
                    try tiffData.write(to: pageURL)
                }
            } else {
                guard let tiffData = result.image.tiffRepresentation else {
                    throw ScannerError.scanFailed
                }
                try tiffData.write(to: fileURL)
            }

        case .pdf:
            // Create multi-page PDF from all images (uncompressed)
            let pdfDocument = PDFDocument()
            for (index, image) in images.enumerated() {
                if let pdfPage = PDFPage(image: image) {
                    pdfDocument.insert(pdfPage, at: index)
                } else {
                    logger.warning("Failed to create PDF page from image \(index + 1)")
                }
            }

            // Add metadata
            var attributes: [PDFDocumentAttribute: Any] = [:]
            attributes[.creatorAttribute] = "ScanFlow"
            attributes[.producerAttribute] = "ScanFlow Scanner App"
            attributes[.creationDateAttribute] = Date()
            pdfDocument.documentAttributes = attributes

            guard pdfDocument.write(to: fileURL) else {
                throw ScannerError.scanFailed
            }
            logger.info("Created \(pageCount)-page PDF at \(fileURL.path)")

        case .compressedPDF:
            // Create compressed multi-page PDF using JPEG-compressed images
            let pdfDocument = PDFDocument()
            for (index, image) in images.enumerated() {
                guard let tiffData = image.tiffRepresentation,
                      let bitmapImage = NSBitmapImageRep(data: tiffData),
                      let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: preset.quality]),
                      let jpegImage = NSImage(data: jpegData),
                      let pdfPage = PDFPage(image: jpegImage) else {
                    logger.warning("Failed to create compressed PDF page from image \(index + 1)")
                    continue
                }
                pdfDocument.insert(pdfPage, at: index)
            }

            // Add metadata
            var attributes: [PDFDocumentAttribute: Any] = [:]
            attributes[.creatorAttribute] = "ScanFlow"
            attributes[.producerAttribute] = "ScanFlow Scanner App"
            attributes[.creationDateAttribute] = Date()
            pdfDocument.documentAttributes = attributes

            guard pdfDocument.write(to: fileURL) else {
                throw ScannerError.scanFailed
            }
            logger.info("Created \(pageCount)-page compressed PDF at \(fileURL.path)")
        }

        // Get file size
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = fileAttributes[.size] as? Int64 ?? 0

        return ScannedFile(
            filename: filename,
            fileURL: fileURL,
            size: fileSize,
            resolution: result.metadata.resolution,
            dateScanned: result.metadata.timestamp,
            scannerModel: result.metadata.scannerModel,
            format: preset.format
        )
    }
    #endif

    private func generateFilename(format: ScanFormat) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())

        // Determine file extension
        let fileExtension: String
        switch format {
        case .pdf, .compressedPDF:
            fileExtension = "pdf"
        case .jpeg:
            fileExtension = "jpeg"
        case .tiff:
            fileExtension = "tiff"
        case .png:
            fileExtension = "png"
        }

        // Find next available number
        var counter = 1
        var filename = "\(dateString)_\(String(format: "%03d", counter)).\(fileExtension)"

        let destPath = NSString(string: scanDestination).expandingTildeInPath
        let destURL = URL(fileURLWithPath: destPath)

        while FileManager.default.fileExists(atPath: destURL.appendingPathComponent(filename).path) {
            counter += 1
            filename = "\(dateString)_\(String(format: "%03d", counter)).\(fileExtension)"
        }

        return filename
    }

    func showAlert(message: String) {
        alertMessage = message
        showingAlert = true
    }
}
