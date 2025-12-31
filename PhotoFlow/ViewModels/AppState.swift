//
//  AppState.swift
//  PhotoFlow
//
//  Created by Claude on 2024-12-30.
//

import Foundation
import SwiftUI

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

    // Barcode Settings
    var barcodeEnabled: Bool {
        get { _settings.barcodeEnabled }
        set { _settings.barcodeEnabled = newValue }
    }
    var barcodeUseForNaming: Bool {
        get { _settings.barcodeUseForNaming }
        set { _settings.barcodeUseForNaming = newValue }
    }
    var barcodeUseForSplitting: Bool {
        get { _settings.barcodeUseForSplitting }
        set { _settings.barcodeUseForSplitting = newValue }
    }
    var barcodeSplitPattern: String {
        get { _settings.barcodeSplitPattern }
        set { _settings.barcodeSplitPattern = newValue }
    }
    var barcodeUseForFolderRouting: Bool {
        get { _settings.barcodeUseForFolderRouting }
        set { _settings.barcodeUseForFolderRouting = newValue }
    }
    var barcodeAddToMetadata: Bool {
        get { _settings.barcodeAddToMetadata }
        set { _settings.barcodeAddToMetadata = newValue }
    }
    var barcodeMinimumConfidence: Double {
        get { _settings.barcodeMinimumConfidence }
        set { _settings.barcodeMinimumConfidence = newValue }
    }

    // Imprinter Settings
    var imprinterEnabled: Bool {
        get { _settings.imprinterEnabled }
        set { _settings.imprinterEnabled = newValue }
    }
    var imprinterText: String {
        get { _settings.imprinterText }
        set { _settings.imprinterText = newValue }
    }
    var imprinterPosition: String {
        get { _settings.imprinterPosition }
        set { _settings.imprinterPosition = newValue }
    }
    var imprinterRotation: Int {
        get { _settings.imprinterRotation }
        set { _settings.imprinterRotation = newValue }
    }
    var imprinterOpacity: Double {
        get { _settings.imprinterOpacity }
        set { _settings.imprinterOpacity = newValue }
    }
    var imprinterFontSize: Double {
        get { _settings.imprinterFontSize }
        set { _settings.imprinterFontSize = newValue }
    }
    var imprinterFontName: String {
        get { _settings.imprinterFontName }
        set { _settings.imprinterFontName = newValue }
    }
    var imprinterTextColor: String {
        get { _settings.imprinterTextColor }
        set { _settings.imprinterTextColor = newValue }
    }
    var imprinterIncludeDate: Bool {
        get { _settings.imprinterIncludeDate }
        set { _settings.imprinterIncludeDate = newValue }
    }
    var imprinterIncludeTime: Bool {
        get { _settings.imprinterIncludeTime }
        set { _settings.imprinterIncludeTime = newValue }
    }
    var imprinterIncludePageNumbers: Bool {
        get { _settings.imprinterIncludePageNumbers }
        set { _settings.imprinterIncludePageNumbers = newValue }
    }

    init() {
        // Initialize with user defaults if needed
        loadPresets()
    }

    func loadPresets() {
        // Load custom presets from UserDefaults if available
        if let data = UserDefaults.standard.data(forKey: "customPresets"),
           let customPresets = try? JSONDecoder().decode([ScanPreset].self, from: data) {
            presets = ScanPreset.defaults + customPresets
        }
    }

    func savePresets() {
        let customPresets = presets.filter { preset in
            !ScanPreset.defaults.contains { $0.id == preset.id }
        }
        if let data = try? JSONEncoder().encode(customPresets) {
            UserDefaults.standard.set(data, forKey: "customPresets")
        }
    }

    func addToQueue(preset: ScanPreset, count: Int = 1) {
        for i in 0..<count {
            let scan = QueuedScan(
                name: "Scan \(scanQueue.count + i + 1)",
                preset: preset
            )
            scanQueue.append(scan)
        }
    }

    func removeFromQueue(scan: QueuedScan) {
        scanQueue.removeAll { $0.id == scan.id }
    }

    func startScanning() async {
        guard !scanQueue.isEmpty else { return }
        isScanning = true

        for index in scanQueue.indices where scanQueue[index].status == .pending {
            scanQueue[index].status = .scanning

            do {
                #if os(macOS)
                let result = try await scannerManager.scan(with: scanQueue[index].preset)

                // Save the scanned file
                scanQueue[index].status = .processing
                let savedFile = try await saveScannedImage(result, preset: scanQueue[index].preset)
                scannedFiles.append(savedFile)

                scanQueue[index].status = .completed
                #endif
            } catch {
                scanQueue[index].status = .failed(error.localizedDescription)
                showAlert(message: "Scan failed: \(error.localizedDescription)")
            }
        }

        isScanning = false
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

        // Save image
        guard let tiffData = result.image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
            throw ScannerError.scanFailed
        }

        let imageData: Data?
        switch preset.format {
        case .jpeg:
            imageData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: preset.quality])
        case .png:
            imageData = bitmapImage.representation(using: .png, properties: [:])
        case .tiff:
            imageData = tiffData
        }

        guard let data = imageData else {
            throw ScannerError.scanFailed
        }

        try data.write(to: fileURL)

        return ScannedFile(
            filename: filename,
            fileURL: fileURL,
            size: Int64(data.count),
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

        // Find next available number
        var counter = 1
        var filename = "\(dateString)_\(String(format: "%03d", counter)).\(format.rawValue.lowercased())"

        let destPath = NSString(string: scanDestination).expandingTildeInPath
        let destURL = URL(fileURLWithPath: destPath)

        while FileManager.default.fileExists(atPath: destURL.appendingPathComponent(filename).path) {
            counter += 1
            filename = "\(dateString)_\(String(format: "%03d", counter)).\(format.rawValue.lowercased())"
        }

        return filename
    }

    func showAlert(message: String) {
        alertMessage = message
        showingAlert = true
    }
}
