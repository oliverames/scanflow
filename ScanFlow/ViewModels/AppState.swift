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
import AppKit
import PDFKit
import ServiceManagement
import ImageCaptureCore
#endif

private let logger = Logger(subsystem: "com.scanflow.app", category: "AppState")
private let presetsStorageKey = "customPresets"

private struct PresetStorePayload: Codable {
    let schemaVersion: Int
    let customPresets: [ScanPreset]
}

public enum NavigationSection: String, CaseIterable, Identifiable {
    case scan = "Scan"
    case queue = "Scan Queue"
    case library = "Scanned Files"
    case presets = "Scan Presets"

    public var id: String { rawValue }

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
public class AppState {
    public var scannerManager: ScannerManager
    @ObservationIgnored private var scanExecutor: ScanExecuting
    #if os(macOS)
    var twainBridge: TWAINBridge
    var imageProcessor: ImageProcessor
    var documentActionService: DocumentActionService
    @ObservationIgnored private lazy var remoteScanServer: RemoteScanServer = RemoteScanServer(scanHandler: { [weak self] request in
        guard let self else {
            throw RemoteScanServer.ServerError.serverUnavailable
        }
        return try await self.performRemoteScan(request)
    }, authorizeRequest: { [weak self] request in
        guard let self else { return false }
        return self.isRemoteScanAuthorized(request)
    })
    #else
    var remoteScanClient: RemoteScanClient
    #endif
    var scanQueue: [QueuedScan] = []
    var scannedFiles: [ScannedFile] = []
    public var presets: [ScanPreset] = ScanPreset.defaults
    public var currentPreset: ScanPreset = ScanPreset.quickScan
    public var selectedSection: NavigationSection = .scan
    var isScanning: Bool = false
    var showingAlert: Bool = false
    var alertMessage: String = ""
    var showScanSettings: Bool = true
    var showScannerSelection: Bool = false
    var isBackgroundModeEnabled: Bool = false

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
        set {
            _settings.useMockScanner = newValue
            scannerManager.useMockScanner = newValue
        }
    }

    var keepConnectedInBackground: Bool {
        get { _settings.keepConnectedInBackground }
        set { _settings.keepConnectedInBackground = newValue }
    }

    var shouldPromptForBackgroundConnection: Bool {
        get { _settings.shouldPromptForBackgroundConnection }
        set { _settings.shouldPromptForBackgroundConnection = newValue }
    }

    var hasConnectedScanner: Bool {
        get { _settings.hasConnectedScanner }
        set { _settings.hasConnectedScanner = newValue }
    }

    var autoStartScanWhenReady: Bool {
        get { _settings.autoStartScanWhenReady }
        set { _settings.autoStartScanWhenReady = newValue }
    }

    var startAtLogin: Bool {
        get { _settings.startAtLogin }
        set { _settings.startAtLogin = newValue }
    }

    var remoteScanServerEnabled: Bool {
        get { _settings.remoteScanServerEnabled }
        set { _settings.remoteScanServerEnabled = newValue }
    }

    var remoteScanRequirePairingToken: Bool {
        get { _settings.remoteScanRequirePairingToken }
        set { _settings.remoteScanRequirePairingToken = newValue }
    }

    var remoteScanPairingToken: String {
        get { _settings.remoteScanPairingToken }
        set { _settings.remoteScanPairingToken = newValue.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    var remoteScanClientPairingToken: String {
        get { _settings.remoteScanClientPairingToken }
        set { _settings.remoteScanClientPairingToken = newValue.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    var autoStartScannerIDs: Set<String> {
        get { _settings.autoStartScannerIDs }
        set { _settings.autoStartScannerIDs = newValue }
    }

    var menuBarAlwaysEnabled: Bool {
        get { _settings.menuBarAlwaysEnabled }
        set { _settings.menuBarAlwaysEnabled = newValue }
    }

    var scannerDiscoveryTimeoutSeconds: Int {
        get { _settings.scannerDiscoveryTimeoutSeconds }
        set {
            let clamped = min(max(newValue, 1), 15)
            _settings.scannerDiscoveryTimeoutSeconds = clamped
            scannerManager.discoveryTimeoutSeconds = clamped
        }
    }

    var scanTimeoutSeconds: Int {
        get { _settings.scanTimeoutSeconds }
        set {
            let clamped = min(max(newValue, 30), 900)
            _settings.scanTimeoutSeconds = clamped
            scannerManager.scanTimeoutSeconds = clamped
        }
    }

    var preserveTemporaryScanFiles: Bool {
        get { _settings.preserveTemporaryScanFiles }
        set {
            _settings.preserveTemporaryScanFiles = newValue
            scannerManager.preserveTemporaryScanFiles = newValue
        }
    }

    var maxBufferedPages: Int {
        get { _settings.maxBufferedPages }
        set {
            let clamped = min(max(newValue, 25), 500)
            _settings.maxBufferedPages = clamped
            scannerManager.maxBufferedPages = clamped
        }
    }

    /// Tracks whether a scan was performed during this app session (not persisted)
    var didScanThisSession: Bool = false

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

    init(scanExecutor: ScanExecuting? = nil) {
        let manager = ScannerManager()
        self.scannerManager = manager
        #if os(macOS)
        self.twainBridge = TWAINBridge(scannerManager: manager)
        #endif
        self.scanExecutor = scanExecutor ?? manager
        logger.info("AppState initializing...")
        #if os(macOS)
        let processor = ImageProcessor()
        imageProcessor = processor
        documentActionService = DocumentActionService(imageProcessor: processor)
        ensureRemotePairingToken()
        applyRuntimeScannerSettings()
        if remoteScanServerEnabled {
            remoteScanServer.start()
        }
        scannerManager.onDeviceReady = { [weak self] device in
            self?.handleScannerReadyForAutoScan(device: device)
        }
        scannerManager.onScannerDiscovered = { [weak self] scanner in
            self?.handleScannerDiscovered(scanner)
        }
        if keepConnectedInBackground && !startAtLogin {
            startAtLogin = true
        }
        if keepConnectedInBackground {
            scannerManager.startBrowsing()
        }
        updateLoginItemRegistration(enabled: startAtLogin)
        #endif
        #if os(iOS)
        remoteScanClient = RemoteScanClient()
        remoteScanClient.onScanResult = { [weak self] result in
            Task { @MainActor in
                self?.handleRemoteScanResult(result)
            }
        }
        remoteScanClient.startBrowsing()
        #endif
        loadPresets()
        logger.info("AppState initialized with \(self.presets.count) presets")
    }

    public convenience init() {
        self.init(scanExecutor: nil)
    }

    private func applyRuntimeScannerSettings() {
        scannerManager.useMockScanner = useMockScanner
        scannerManager.discoveryTimeoutSeconds = min(max(_settings.scannerDiscoveryTimeoutSeconds, 1), 15)
        scannerManager.scanTimeoutSeconds = min(max(_settings.scanTimeoutSeconds, 30), 900)
        scannerManager.preserveTemporaryScanFiles = _settings.preserveTemporaryScanFiles
        scannerManager.maxBufferedPages = min(max(_settings.maxBufferedPages, 25), 500)
        if scanExecutor === scannerManager {
            scanExecutor = scannerManager
        }
    }

    func setScanExecutorForTesting(_ executor: ScanExecuting) {
        scanExecutor = executor
    }

    private func ensureRemotePairingToken() {
        if _settings.remoteScanPairingToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            _settings.remoteScanPairingToken = Self.generatePairingToken()
        }
    }

    func loadPresets() {
        logger.info("Loading presets from UserDefaults")
        guard let data = UserDefaults.standard.data(forKey: presetsStorageKey) else {
            logger.info("No custom presets found, using defaults")
            return
        }

        do {
            let payload = try JSONDecoder().decode(PresetStorePayload.self, from: data)
            let customPresets = migrateCustomPresets(payload.customPresets, from: payload.schemaVersion)
            presets = ScanPreset.defaults + customPresets
            logger.info("Loaded \(customPresets.count) custom presets")
        } catch {
            logger.warning("Failed to decode versioned payload, attempting legacy format")
            do {
                let legacyPresets = try JSONDecoder().decode([ScanPreset].self, from: data)
                let migrated = migrateCustomPresets(legacyPresets, from: 1)
                presets = ScanPreset.defaults + migrated
                savePresets()
                logger.info("Migrated \(migrated.count) legacy custom presets to schema v2")
            } catch {
                logger.error("Failed to decode custom presets: \(error.localizedDescription). Using defaults.")
                presets = ScanPreset.defaults
            }
        }
    }

    func savePresets() {
        let customPresets = presets.filter { preset in
            !ScanPreset.defaults.contains { $0.id == preset.id }
        }
        do {
            let payload = PresetStorePayload(schemaVersion: 2, customPresets: customPresets)
            let data = try JSONEncoder().encode(payload)
            UserDefaults.standard.set(data, forKey: presetsStorageKey)
            logger.info("Saved \(customPresets.count) custom presets")
        } catch {
            logger.error("Failed to encode presets: \(error.localizedDescription)")
        }
    }

    private func migrateCustomPresets(_ input: [ScanPreset], from schemaVersion: Int) -> [ScanPreset] {
        input.map { preset in
            var migrated = preset
            migrated.name = migrated.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if migrated.name.isEmpty {
                migrated.name = "Untitled Preset"
            }

            // Keep legacy data safe across schema revisions.
            migrated.resolution = min(max(migrated.resolution, 75), 2400)
            migrated.splitPageNumber = max(1, migrated.splitPageNumber)
            migrated.blankPageSensitivity = min(max(migrated.blankPageSensitivity, 0), 1)
            migrated.bwThreshold = min(max(migrated.bwThreshold, 0), 255)
            if migrated.destination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                migrated.destination = scanDestination
            }

            if schemaVersion < 2, migrated.timerSeconds < 0.1 {
                migrated.timerSeconds = 1.5
            }
            return migrated
        }
    }

    public func addToQueue(preset: ScanPreset, count: Int = 1) {
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

    public func startScanning() async {
        guard !scanQueue.isEmpty else {
            logger.warning("startScanning called but queue is empty")
            return
        }

        logger.info("Starting scan process with \(self.scanQueue.count) items in queue")
        isScanning = true

        func updateQueueStatus(id: UUID, status: ScanStatus) {
            if let currentIndex = scanQueue.firstIndex(where: { $0.id == id }) {
                scanQueue[currentIndex].status = status
            }
        }

        while let pending = scanQueue.first(where: { $0.status == .pending }) {
            let scanID = pending.id
            let preset = pending.preset
            let scanName = pending.name

            guard scanQueue.contains(where: { $0.id == scanID && $0.status == .pending }) else {
                continue
            }

            #if os(macOS)
            if !confirmScanIfNeeded(preset) {
                updateQueueStatus(id: scanID, status: .failed("Cancelled"))
                continue
            }
            #endif

            logger.info("Processing queue item: \(scanName)")
            updateQueueStatus(id: scanID, status: .scanning)

            var attempt = 0
            let maxAttempts = 2
            while attempt <= maxAttempts {
                do {
                    #if os(macOS)
                    if preset.useTimer {
                        let delay = max(0.1, preset.timerSeconds)
                        try? await Task.sleep(for: .seconds(delay))
                    }
                    logger.info("Initiating scan with preset: \(preset.name), attempt \(attempt + 1)")
                    let result = try await scanExecutor.scan(with: preset)
                    logger.info("Scan completed, processing image...")

                    updateQueueStatus(id: scanID, status: .processing)
                    let savedFiles = try await saveScannedImage(result, preset: preset)
                    scannedFiles.append(contentsOf: savedFiles)
                    if let firstFile = savedFiles.first {
                        logger.info("Image saved to: \(firstFile.fileURL.path)")
                    }

                    updateQueueStatus(id: scanID, status: .completed)
                    didScanThisSession = true
                    logger.info("Scan completed successfully: \(scanName)")
                    if preset.askForMorePages, preset.source == .flatbed, shouldScanAnotherPage() {
                        addToQueue(preset: preset, count: 1)
                    }
                    #endif
                    #if os(iOS)
                    guard remoteScanClient.connectionState == .connected else {
                        updateQueueStatus(id: scanID, status: .failed("Not connected to a Mac"))
                        showAlert(message: "Connect to a Mac scanner before starting a remote scan.")
                        break
                    }

                    let result = try await remoteScanClient.performScan(
                        presetName: preset.name,
                        searchablePDF: preset.searchablePDF,
                        forceSingleDocument: !preset.separationSettings.enabled,
                        pairingToken: remoteScanClientPairingToken
                    )

                    updateQueueStatus(id: scanID, status: .processing)
                    handleRemoteScanResult(result)
                    updateQueueStatus(id: scanID, status: .completed)
                    didScanThisSession = true
                    #endif
                    break
                } catch {
                    let isLastAttempt = attempt >= maxAttempts
                    logger.error("Scan attempt \(attempt + 1) failed: \(error.localizedDescription)")

                    #if os(macOS)
                    let shouldRetry: Bool
                    if scanExecutor === scannerManager {
                        shouldRetry = await attemptRecoveryIfNeeded(after: error)
                    } else {
                        shouldRetry = isTransientScannerError(error)
                    }
                    #else
                    let shouldRetry = false
                    #endif

                    if !isLastAttempt, shouldRetry {
                        attempt += 1
                        updateQueueStatus(id: scanID, status: .scanning)
                        continue
                    }

                    updateQueueStatus(id: scanID, status: .failed(error.localizedDescription))
                    showAlert(message: "Scan failed: \(error.localizedDescription)")
                    break
                }
            }
        }

        isScanning = false
        logger.info("Scan process completed")
    }

    #if os(macOS)
    private func attemptRecoveryIfNeeded(after error: Error) async -> Bool {
        guard isTransientScannerError(error) else {
            return false
        }

        logger.info("Attempting scanner recovery after transient failure")
        guard let scanner = scannerManager.selectedScanner else {
            return false
        }

        if scannerManager.connectionState.isConnected {
            await scannerManager.disconnect()
        }

        do {
            try await Task.sleep(for: .milliseconds(750))
            try await scannerManager.connect(to: scanner)
            return scannerManager.connectionState.isConnected
        } catch {
            logger.error("Scanner recovery failed: \(error.localizedDescription)")
            return false
        }
    }

    private func isTransientScannerError(_ error: Error) -> Bool {
        if let scannerError = error as? ScannerError {
            switch scannerError {
            case .scanTimeout, .notConnected, .connectionFailed:
                return true
            case .scanCancelled, .scanFailed, .noScannersFound, .noFunctionalUnit:
                return false
            }
        }

        let description = error.localizedDescription.lowercased()
        let transientHints = [
            "timed out",
            "timeout",
            "disconnected",
            "not connected",
            "paper jam",
            "busy"
        ]
        return transientHints.contains { description.contains($0) }
    }
    #endif

    #if os(macOS)
    private func saveScannedImage(_ result: ScanResult, preset: ScanPreset) async throws -> [ScannedFile] {
        let destPath = NSString(string: preset.destination).expandingTildeInPath
        var destURL = URL(fileURLWithPath: destPath)
        if let subfolder = organizationSubfolder(for: result.metadata.timestamp) {
            destURL = destURL.appendingPathComponent(subfolder, isDirectory: true)
        }

        do {
            try FileManager.default.createDirectory(at: destURL, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create destination directory: \(error.localizedDescription)")
            throw error
        }

        let images = try await prepareOutputPages(from: result.images, preset: preset)
        let pageCount = images.count
        logger.info("Saving \(pageCount) page(s) to \(destURL.path)")

        var savedFiles: [ScannedFile] = []
        var sequenceCounter = preset.useSequenceNumber ? preset.sequenceStartNumber : 0

        func fallbackBaseName() -> String {
            let trimmedTemplate = fileNamingTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedTemplate.isEmpty {
                let baseName = baseNameFromTemplate(
                    scanDate: result.metadata.timestamp,
                    sequenceNumber: sequenceCounter
                )
                if trimmedTemplate.contains("###") {
                    sequenceCounter += 1
                }
                return baseName
            }
            var nameParts: [String] = []
            let prefix = preset.fileNamePrefix.trimmingCharacters(in: .whitespacesAndNewlines)
            if !prefix.isEmpty {
                nameParts.append(prefix)
            }
            if preset.uniqueDateTag {
                nameParts.append(dateTagString())
            }
            if preset.useSequenceNumber {
                nameParts.append(String(format: "%03d", sequenceCounter))
                sequenceCounter += 1
            }
            return nameParts.isEmpty ? dateTagString() : nameParts.joined(separator: "")
        }

        func finalizeFile(url: URL, filename: String) throws {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            savedFiles.append(ScannedFile(
                filename: filename,
                fileURL: url,
                size: fileSize,
                resolution: result.metadata.resolution,
                dateScanned: result.metadata.timestamp,
                scannerModel: result.metadata.scannerModel,
                format: preset.format
            ))
        }

        func resolveDestinationURL(for filename: String) -> URL {
            let url = destURL.appendingPathComponent(filename)
            guard FileManager.default.fileExists(atPath: url.path) else {
                return url
            }
            switch preset.existingFileBehavior {
            case .overwrite:
                return url
            case .askUser:
                showAlert(message: "File already exists. Using next available filename.")
                fallthrough
            case .increaseSequence:
                return destURL.appendingPathComponent(nextAvailableFilename(startingWith: filename, in: destURL))
            }
        }

        var documents: [[NSImage]] = [images]
        if preset.separationSettings.enabled {
            let separator = DocumentSeparator(imageProcessor: imageProcessor, barcodeRecognizer: BarcodeRecognizer())
            let separationResult = try await separator.separateDocuments(pages: images, settings: preset.separationSettings)
            documents = separationResult.documents
        } else if preset.splitOnPage, pageCount > 1 {
            documents = splitPages(pages: images, chunkSize: preset.splitPageNumber)
        }

        let extensionString = fileExtension(for: preset.format)
        let aiNamer = AIFileNamer(imageProcessor: imageProcessor)
        let maxPagesPerDocument = 200

        for (documentIndex, documentPages) in documents.enumerated() {
            if documentPages.count > maxPagesPerDocument {
                logger.error("Document contains \(documentPages.count) pages, exceeding safety limit \(maxPagesPerDocument)")
                throw ScannerError.scanFailed
            }

            let baseName = await preferredBaseName(
                for: documentPages,
                documentIndex: documentIndex,
                preset: preset,
                aiNamer: aiNamer,
                fallback: fallbackBaseName
            )

            switch preset.format {
            case .jpeg:
                for (index, image) in documentPages.enumerated() {
                    guard let imageData = autoreleasepool(invoking: { () -> Data? in
                        guard let tiffData = image.tiffRepresentation,
                              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
                            return nil
                        }
                        return bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: preset.quality])
                    }) else {
                        throw ScannerError.scanFailed
                    }
                    let filename = filenameForDocument(baseName: baseName, extensionString: extensionString, pageIndex: documentPages.count > 1 ? index : nil)
                    let targetURL = resolveDestinationURL(for: filename)
                    try imageData.write(to: targetURL)
                    try finalizeFile(url: targetURL, filename: targetURL.lastPathComponent)
                }

            case .png:
                for (index, image) in documentPages.enumerated() {
                    guard let imageData = autoreleasepool(invoking: { () -> Data? in
                        guard let tiffData = image.tiffRepresentation,
                              let bitmapImage = NSBitmapImageRep(data: tiffData) else {
                            return nil
                        }
                        return bitmapImage.representation(using: .png, properties: [:])
                    }) else {
                        throw ScannerError.scanFailed
                    }
                    let filename = filenameForDocument(baseName: baseName, extensionString: extensionString, pageIndex: documentPages.count > 1 ? index : nil)
                    let targetURL = resolveDestinationURL(for: filename)
                    try imageData.write(to: targetURL)
                    try finalizeFile(url: targetURL, filename: targetURL.lastPathComponent)
                }

            case .tiff:
                for (index, image) in documentPages.enumerated() {
                    guard let tiffData = autoreleasepool(invoking: { image.tiffRepresentation }) else {
                        throw ScannerError.scanFailed
                    }
                    let filename = filenameForDocument(baseName: baseName, extensionString: extensionString, pageIndex: documentPages.count > 1 ? index : nil)
                    let targetURL = resolveDestinationURL(for: filename)
                    try tiffData.write(to: targetURL)
                    try finalizeFile(url: targetURL, filename: targetURL.lastPathComponent)
                }

            case .pdf:
                let pdfDocument = PDFDocument()
                for (index, image) in documentPages.enumerated() {
                    if let pdfPage = autoreleasepool(invoking: { PDFPage(image: image) }) {
                        if preset.searchablePDF {
                            if let text = try? await imageProcessor.recognizeText(image), !text.isEmpty {
                                addTextAnnotation(to: pdfPage, text: text)
                            }
                        }
                        pdfDocument.insert(pdfPage, at: index)
                    } else {
                        logger.warning("Failed to create PDF page from image \(index + 1)")
                    }
                }
                applyPDFMetadata(to: pdfDocument)
                let filename = filenameForDocument(baseName: baseName, extensionString: extensionString, pageIndex: nil)
                let targetURL = resolveDestinationURL(for: filename)
                guard pdfDocument.write(to: targetURL) else {
                    throw ScannerError.scanFailed
                }
                try finalizeFile(url: targetURL, filename: targetURL.lastPathComponent)

            case .compressedPDF:
                let pdfDocument = PDFDocument()
                for (index, image) in documentPages.enumerated() {
                    guard let pdfPage = autoreleasepool(invoking: { () -> PDFPage? in
                        guard let tiffData = image.tiffRepresentation,
                              let bitmapImage = NSBitmapImageRep(data: tiffData),
                              let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: preset.quality]),
                              let jpegImage = NSImage(data: jpegData) else {
                            return nil
                        }
                        return PDFPage(image: jpegImage)
                    }) else {
                        logger.warning("Failed to create compressed PDF page from image \(index + 1)")
                        continue
                    }
                    if preset.searchablePDF {
                        if let text = try? await imageProcessor.recognizeText(image), !text.isEmpty {
                            addTextAnnotation(to: pdfPage, text: text)
                        }
                    }
                    pdfDocument.insert(pdfPage, at: index)
                }
                applyPDFMetadata(to: pdfDocument)
                let filename = filenameForDocument(baseName: baseName, extensionString: extensionString, pageIndex: nil)
                let targetURL = resolveDestinationURL(for: filename)
                guard pdfDocument.write(to: targetURL) else {
                    throw ScannerError.scanFailed
                }
                try finalizeFile(url: targetURL, filename: targetURL.lastPathComponent)
            }
        }

        openSavedFilesIfNeeded(savedFiles: savedFiles, preset: preset)
        if autoOpenDestination, let folderURL = savedFiles.first?.fileURL.deletingLastPathComponent() {
            NSWorkspace.shared.open(folderURL)
        }

        return savedFiles
    }

    func performRemoteScan(_ request: RemoteScanRequest) async throws -> RemoteScanResult {
        if isScanning {
            throw RemoteScanServer.ServerError.busy
        }

        isScanning = true
        defer { isScanning = false }

        let preset = presets.first { $0.name == request.presetName } ?? currentPreset
        let result = try await scannerManager.scan(with: preset)
        let savedFiles = try await saveScannedImage(result, preset: preset)
        scannedFiles.append(contentsOf: savedFiles)

        let documents = try await createRemoteDocuments(
            from: result.images,
            preset: preset,
            searchable: request.searchablePDF,
            forceSingleDocument: request.forceSingleDocument
        )
        let scannedAt = Date()
        let totalBytes = documents.reduce(0) { $0 + $1.byteCount }

        return RemoteScanResult(documents: documents, totalBytes: totalBytes, scannedAt: scannedAt)
    }

    private func createRemoteDocuments(
        from pages: [NSImage],
        preset: ScanPreset,
        searchable: Bool,
        forceSingleDocument: Bool
    ) async throws -> [RemoteScanDocument] {
        let preparedPages = try await prepareOutputPages(from: pages, preset: preset)
        var documents: [[NSImage]] = [preparedPages]
        if !forceSingleDocument {
            if preset.separationSettings.enabled {
                let separator = DocumentSeparator(imageProcessor: imageProcessor, barcodeRecognizer: BarcodeRecognizer())
                let separationResult = try await separator.separateDocuments(pages: preparedPages, settings: preset.separationSettings)
                documents = separationResult.documents
            } else if preset.splitOnPage, preparedPages.count > 1 {
                documents = splitPages(pages: preparedPages, chunkSize: preset.splitPageNumber)
            }
        }

        var results: [RemoteScanDocument] = []

        for (index, docPages) in documents.enumerated() {
            let pdfData = try await createRemotePDFData(from: docPages, searchable: searchable)
            let filename = remoteDocumentFilename(base: preset.name, index: documents.count > 1 ? index : nil)
            results.append(
                RemoteScanDocument(
                    filename: filename,
                    pdfDataBase64: pdfData.base64EncodedString(),
                    pageCount: docPages.count,
                    byteCount: pdfData.count
                )
            )
        }

        return results
    }

    private func prepareOutputPages(from inputPages: [NSImage], preset: ScanPreset) async throws -> [NSImage] {
        guard !inputPages.isEmpty else {
            throw ScannerError.scanFailed
        }

        var outputPages: [NSImage] = []
        let shouldProcess = shouldRunImageProcessing(for: preset)
        let blankThreshold = blankDetectionThreshold(sensitivity: preset.blankPageSensitivity)
        var blankPagesDetected = 0
        var blankPagesDeleted = 0

        for (index, originalPage) in inputPages.enumerated() {
            var page = originalPage
            if shouldProcess {
                do {
                    page = try await imageProcessor.process(page, with: preset)
                } catch {
                    logger.warning("Image processing failed for page \(index + 1): \(error.localizedDescription). Using original page.")
                    page = originalPage
                }
            }

            if preset.rotateEvenPages, index.isMultiple(of: 2) == false {
                if let rotated = rotateImage(page, byDegrees: 180) {
                    page = rotated
                }
            }

            let variants = splitBookPagesIfNeeded(page, preset: preset)
            for variant in variants {
                if preset.blankPageHandling == .keep {
                    outputPages.append(variant)
                    continue
                }

                let isBlank = await imageProcessor.isBlankPage(variant, threshold: blankThreshold)
                guard isBlank else {
                    outputPages.append(variant)
                    continue
                }

                blankPagesDetected += 1
                switch preset.blankPageHandling {
                case .keep:
                    outputPages.append(variant)
                case .askUser:
                    // The queue scan flow is non-interactive; keep the page and notify once.
                    outputPages.append(variant)
                case .delete:
                    blankPagesDeleted += 1
                }
            }
        }

        if preset.blankPageHandling == .askUser, blankPagesDetected > 0 {
            showAlert(message: "Detected \(blankPagesDetected) blank page(s). Ask mode keeps blank pages; choose Delete to remove them automatically.")
        }

        if blankPagesDeleted > 0 {
            logger.info("Removed \(blankPagesDeleted) blank page(s) before export")
        }

        if outputPages.isEmpty {
            logger.error("All pages were filtered out before saving")
            throw ScannerError.scanFailed
        }

        return outputPages
    }

    private func shouldRunImageProcessing(for preset: ScanPreset) -> Bool {
        if preset.autoRotate || preset.autoCrop || preset.deskew || preset.restoreColor || preset.removeRedEye {
            return true
        }
        if preset.mediaDetection != .none || preset.rotationAngle != .none || preset.descreen || preset.sharpen || preset.invertColors {
            return true
        }
        if abs(preset.brightness) > 0.001 || abs(preset.contrast) > 0.001 || abs(preset.hue) > 0.001 || abs(preset.saturation) > 0.001 || abs(preset.lightness) > 0.001 {
            return true
        }
        if abs(preset.gamma - 2.2) > 0.01 {
            return true
        }
        return false
    }

    private func blankDetectionThreshold(sensitivity: Double) -> Double {
        max(0.78, 0.98 - (sensitivity * 0.20))
    }

    private func splitBookPagesIfNeeded(_ image: NSImage, preset: ScanPreset) -> [NSImage] {
        guard preset.splitBookPages else {
            return [image]
        }

        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil), cgImage.width > 1 else {
            return [image]
        }

        let halfWidth = cgImage.width / 2
        guard halfWidth > 0 else { return [image] }

        let leftRect = CGRect(x: 0, y: 0, width: halfWidth, height: cgImage.height)
        let rightRect = CGRect(x: halfWidth, y: 0, width: cgImage.width - halfWidth, height: cgImage.height)

        guard let left = cgImage.cropping(to: leftRect),
              let right = cgImage.cropping(to: rightRect) else {
            return [image]
        }

        return [
            NSImage(cgImage: left, size: NSSize(width: left.width, height: left.height)),
            NSImage(cgImage: right, size: NSSize(width: right.width, height: right.height))
        ]
    }

    private func rotateImage(_ image: NSImage, byDegrees degrees: CGFloat) -> NSImage? {
        let radians = degrees * .pi / 180
        let sourceRect = CGRect(origin: .zero, size: image.size)
        let rotatedRect = sourceRect.applying(CGAffineTransform(rotationAngle: radians))
        let outputSize = NSSize(width: abs(rotatedRect.width), height: abs(rotatedRect.height))

        let output = NSImage(size: outputSize)
        output.lockFocus()
        defer { output.unlockFocus() }

        let transform = NSAffineTransform()
        transform.translateX(by: outputSize.width / 2, yBy: outputSize.height / 2)
        transform.rotate(byDegrees: degrees)
        transform.translateX(by: -image.size.width / 2, yBy: -image.size.height / 2)
        transform.concat()

        image.draw(at: .zero, from: .zero, operation: .copy, fraction: 1.0)
        return output
    }

    private func remoteDocumentFilename(base: String, index: Int?) -> String {
        let sanitizedBase = sanitizeFilenameInput(base.isEmpty ? "Remote Scan" : base)
        if let index {
            return "\(sanitizedBase)-\(String(format: "%03d", index + 1)).pdf"
        }
        return "\(sanitizedBase).pdf"
    }

    private func createRemotePDFData(from pages: [NSImage], searchable: Bool) async throws -> Data {
        let maxPagesPerDocument = 200
        if pages.count > maxPagesPerDocument {
            logger.error("Remote document contains \(pages.count) pages, exceeding safety limit \(maxPagesPerDocument)")
            throw ScannerError.scanFailed
        }

        let pdfDocument = PDFDocument()

        for (index, image) in pages.enumerated() {
            if let pdfPage = autoreleasepool(invoking: { PDFPage(image: image) }) {
                if searchable {
                    if let text = try? await imageProcessor.recognizeText(image), !text.isEmpty {
                        addTextAnnotation(to: pdfPage, text: text)
                    }
                }
                pdfDocument.insert(pdfPage, at: index)
            }
        }

        applyPDFMetadata(to: pdfDocument)
        if let data = pdfDocument.dataRepresentation() {
            return data
        }

        throw ScannerError.scanFailed
    }
    #endif

    #if os(macOS)
    private func splitPages(pages: [NSImage], chunkSize: Int) -> [[NSImage]] {
        guard chunkSize > 1 else {
            return pages.map { [$0] }
        }
        var chunks: [[NSImage]] = []
        var index = 0
        while index < pages.count {
            let end = min(index + chunkSize, pages.count)
            chunks.append(Array(pages[index..<end]))
            index = end
        }
        return chunks
    }

    private func preferredBaseName(
        for pages: [NSImage],
        documentIndex: Int,
        preset: ScanPreset,
        aiNamer: AIFileNamer,
        fallback: () -> String
    ) async -> String {
        let defaultCandidate = fallback()
        var candidate = defaultCandidate
        var aiNamingError: Error?
        var promptedForFallback = false

        if preset.namingSettings.enabled {
            let availability = await AIFileNamer.isAvailable()
            if availability {
                do {
                    let response = try await aiNamer.suggestFilename(for: pages, settings: preset.namingSettings)
                    let aiCandidate = response.filename.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !aiCandidate.isEmpty {
                        candidate = aiCandidate
                    }
                } catch {
                    aiNamingError = error
                }
            } else {
                aiNamingError = AIFileNamerError.modelUnavailable
            }
        }

        if let aiNamingError {
            switch preset.namingSettings.fallbackBehavior {
            case .promptManual:
                if let previewImage = pages.first {
                    let fallbackLabel = "Document \(documentIndex + 1)"
                    let manualName = promptForFilename(
                        suggested: candidate,
                        preview: previewImage,
                        fallbackLabel: fallbackLabel
                    )
                    if let manualName, !manualName.isEmpty {
                        candidate = manualName
                    } else {
                        showAlert(message: "AI naming failed. Using the default naming pattern.")
                    }
                    promptedForFallback = true
                } else {
                    showAlert(message: "AI naming failed. Using the default naming pattern.")
                }
            case .notifyAndFallback:
                showAlert(message: "AI naming failed (\(aiNamingError.localizedDescription)). Using the default naming pattern.")
            case .silentFallback:
                break
            }
        }

        if preset.editEachFilename, !promptedForFallback, let previewImage = pages.first {
            let fallbackLabel = "Document \(documentIndex + 1)"
            let manualName = promptForFilename(suggested: candidate, preview: previewImage, fallbackLabel: fallbackLabel)
            if let manualName, !manualName.isEmpty {
                candidate = manualName
            }
        }

        let sanitized = sanitizeFilenameInput(candidate)
        return sanitized.isEmpty ? defaultCandidate : sanitized
    }

    #if os(macOS)
    private func confirmScanIfNeeded(_ preset: ScanPreset) -> Bool {
        guard preset.showConfigBeforeScan else { return true }
        let alert = NSAlert()
        alert.messageText = "Start Scan?"
        alert.informativeText = "Scan using preset: \(preset.name)"
        alert.addButton(withTitle: "Start Scan")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func shouldScanAnotherPage() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Scan another page?"
        alert.informativeText = "The scan completed. Would you like to scan another page?"
        alert.addButton(withTitle: "Scan Another")
        alert.addButton(withTitle: "Finish")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func promptForFilename(suggested: String, preview: NSImage, fallbackLabel: String) -> String? {
        let alert = NSAlert()
        alert.messageText = "Edit Filename"
        alert.informativeText = "Confirm the filename for this document."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Use Suggested")

        let imageView = NSImageView(image: preview)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.frame = CGRect(x: 0, y: 0, width: 220, height: 280)

        let textField = NSTextField(string: suggested)
        textField.placeholderString = fallbackLabel

        let stack = NSStackView(views: [imageView, textField])
        stack.orientation = .vertical
        stack.spacing = 12
        stack.alignment = .leading
        alert.accessoryView = stack

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            return sanitizeFilenameInput(textField.stringValue)
        }

        if response == .alertSecondButtonReturn {
            return sanitizeFilenameInput(suggested)
        }

        return nil
    }

    func sanitizeFilenameInput(_ filename: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?*\"<>|")
        let sanitized = filename.components(separatedBy: invalidCharacters).joined(separator: "")
        return sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    #endif

    private func filenameForDocument(baseName: String, extensionString: String, pageIndex: Int?) -> String {
        var name = baseName
        if let pageIndex {
            name += "-\(String(format: "%03d", pageIndex + 1))"
        }
        return "\(name).\(extensionString)"
    }

    private func fileExtension(for format: ScanFormat) -> String {
        switch format {
        case .pdf, .compressedPDF:
            return "pdf"
        case .jpeg:
            return "jpeg"
        case .tiff:
            return "tiff"
        case .png:
            return "png"
        }
    }

    #if os(macOS)
    private func organizationSubfolder(for date: Date) -> String? {
        let formatter = DateFormatter()
        switch organizationPattern {
        case "date":
            formatter.dateFormat = "yyyy-MM-dd"
        case "month":
            formatter.dateFormat = "yyyy-MM"
        default:
            return nil
        }
        return formatter.string(from: date)
    }

    private func baseNameFromTemplate(scanDate: Date, sequenceNumber: Int) -> String {
        let formatter = DateFormatter()
        let sequence = String(format: "%03d", sequenceNumber)
        formatter.dateFormat = fileNamingTemplate.replacingOccurrences(of: "###", with: sequence)
        return formatter.string(from: scanDate)
    }

    private func openSavedFilesIfNeeded(savedFiles: [ScannedFile], preset: ScanPreset) {
        guard preset.openWithApp else { return }
        let appPath = preset.openWithAppPath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !appPath.isEmpty else { return }
        let appURL = URL(fileURLWithPath: appPath)
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            showAlert(message: "Open-with app not found at \(appURL.path)")
            return
        }

        let fileURLs = savedFiles.map(\.fileURL)
        guard !fileURLs.isEmpty else { return }
        NSWorkspace.shared.open(
            fileURLs,
            withApplicationAt: appURL,
            configuration: NSWorkspace.OpenConfiguration(),
            completionHandler: { _, error in
                if let error {
                    logger.error("Failed to open files: \(error.localizedDescription)")
                }
            }
        )
    }
    #endif

    private func dateTagString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        return dateFormatter.string(from: Date())
    }

    private func nextAvailableFilename(startingWith filename: String, in destinationURL: URL) -> String {
        let base = destinationURL.appendingPathComponent(filename).deletingPathExtension().lastPathComponent
        let ext = destinationURL.appendingPathComponent(filename).pathExtension
        var counter = 1
        var candidate = "\(base)-\(counter).\(ext)"
        while FileManager.default.fileExists(atPath: destinationURL.appendingPathComponent(candidate).path) {
            counter += 1
            candidate = "\(base)-\(counter).\(ext)"
        }
        return candidate
    }

    private func applyPDFMetadata(to document: PDFDocument) {
        var attributes: [PDFDocumentAttribute: Any] = [:]
        attributes[.creatorAttribute] = "ScanFlow"
        attributes[.producerAttribute] = "ScanFlow Scanner App"
        attributes[.creationDateAttribute] = Date()
        document.documentAttributes = attributes
    }
    #endif

    #if os(macOS)
    private func addTextAnnotation(to page: PDFPage, text: String) {
        let bounds = page.bounds(for: .mediaBox)
        let annotation = PDFAnnotation(bounds: bounds, forType: .freeText, withProperties: nil)
        annotation.contents = text
        annotation.color = .clear
        annotation.font = NSFont.systemFont(ofSize: 12)
        page.addAnnotation(annotation)
    }
    #endif

    #if os(iOS)
    private func handleRemoteScanResult(_ result: RemoteScanResult) {
        let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory

        var savedCount = 0

        for document in result.documents {
            guard let data = Data(base64Encoded: document.pdfDataBase64) else { continue }

            let filename = sanitizedRemoteFilename(document.filename)
            let targetURL = baseURL.appendingPathComponent(filename)

            do {
                try data.write(to: targetURL, options: [.atomic])
                let fileSize = (try? FileManager.default.attributesOfItem(atPath: targetURL.path)[.size] as? Int64) ?? Int64(data.count)
                let scannedFile = ScannedFile(
                    filename: targetURL.lastPathComponent,
                    fileURL: targetURL,
                    size: fileSize,
                    resolution: 300,
                    dateScanned: result.scannedAt,
                    scannerModel: "Remote Mac",
                    format: .pdf
                )
                scannedFiles.append(scannedFile)
                savedCount += 1
            } catch {
                showAlert(message: "Failed to save remote scan: \(error.localizedDescription)")
                return
            }
        }

        if savedCount > 0 {
            showAlert(message: "Remote scan saved (\(savedCount) document(s))")
        } else {
            showAlert(message: "No remote documents were saved")
        }
    }

    private func sanitizedRemoteFilename(_ filename: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?*\"<>|")
        let sanitized = filename.components(separatedBy: invalidCharacters).joined(separator: "")
        let trimmed = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "Remote Scan.pdf"
        }
        if trimmed.lowercased().hasSuffix(".pdf") {
            return trimmed
        }
        return trimmed + ".pdf"
    }
    #endif

    func showAlert(message: String) {
        alertMessage = message
        showingAlert = true
    }

    func markScannerUsed() {
        hasConnectedScanner = true
    }

    #if os(macOS)
    func revealTemporaryScanFolder() {
        let folder = scannerManager.temporaryScanDirectoryURL
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            NSWorkspace.shared.activateFileViewerSelecting([folder])
        } catch {
            showAlert(message: "Unable to reveal temporary folder: \(error.localizedDescription)")
        }
    }

    func exportDiagnosticsBundle() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let stamp = formatter.string(from: Date())

        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)
        let bundleURL = desktop.appendingPathComponent("ScanFlow-Diagnostics-\(stamp)", isDirectory: true)

        do {
            try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)

            struct DiagnosticsSummary: Codable {
                let generatedAt: Date
                let appVersion: String
                let buildNumber: String
                let osVersion: String
                let scannerConnectionState: String
                let scannerName: String
                let availableScannerNames: [String]
                let queueCount: Int
                let scannedFilesCount: Int
                let currentPreset: String
                let settings: [String: String]
            }

            let settingsSnapshot: [String: String] = [
                "defaultResolution": String(defaultResolution),
                "defaultFormat": defaultFormat,
                "scanDestination": scanDestination,
                "remoteScanServerEnabled": String(remoteScanServerEnabled),
                "remoteScanRequirePairingToken": String(remoteScanRequirePairingToken),
                "menuBarAlwaysEnabled": String(menuBarAlwaysEnabled),
                "keepConnectedInBackground": String(keepConnectedInBackground),
                "autoStartScanWhenReady": String(autoStartScanWhenReady),
                "scannerDiscoveryTimeoutSeconds": String(scannerDiscoveryTimeoutSeconds),
                "scanTimeoutSeconds": String(scanTimeoutSeconds),
                "preserveTemporaryScanFiles": String(preserveTemporaryScanFiles)
                ,"maxBufferedPages": String(maxBufferedPages)
            ]

            let summary = DiagnosticsSummary(
                generatedAt: Date(),
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                buildNumber: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                scannerConnectionState: scannerManager.connectionState.description,
                scannerName: scannerManager.selectedScanner?.name ?? "none",
                availableScannerNames: scannerManager.availableScanners.compactMap(\.name).sorted(),
                queueCount: scanQueue.count,
                scannedFilesCount: scannedFiles.count,
                currentPreset: currentPreset.name,
                settings: settingsSnapshot
            )

            let summaryData = try JSONEncoder.prettyPrinted.encode(summary)
            try summaryData.write(to: bundleURL.appendingPathComponent("summary.json"), options: [.atomic])

            let presetsData = try JSONEncoder.prettyPrinted.encode(presets)
            try presetsData.write(to: bundleURL.appendingPathComponent("presets.json"), options: [.atomic])

            let queueData = try JSONEncoder.prettyPrinted.encode(scanQueue)
            try queueData.write(to: bundleURL.appendingPathComponent("queue.json"), options: [.atomic])

            var notes = "ScanFlow Diagnostics\n"
            notes += "Generated: \(Date())\n"
            notes += "Temporary Scan Folder: \(scannerManager.temporaryScanDirectoryURL.path)\n"
            notes += "Pairing Enabled: \(remoteScanRequirePairingToken)\n"
            try notes.data(using: .utf8)?.write(to: bundleURL.appendingPathComponent("notes.txt"), options: [.atomic])

            NSWorkspace.shared.activateFileViewerSelecting([bundleURL])
        } catch {
            showAlert(message: "Failed to export diagnostics: \(error.localizedDescription)")
        }
    }
    #endif

    func resetSettingsToDefaults() {
        _settings.resetToDefaults()
        ensureRemotePairingToken()
        applyRuntimeScannerSettings()
        #if os(macOS)
        if keepConnectedInBackground {
            scannerManager.startBrowsing()
        } else {
            scannerManager.stopBrowsing()
        }
        if remoteScanServerEnabled {
            remoteScanServer.start()
        } else {
            remoteScanServer.stop()
        }
        updateLoginItemRegistration(enabled: startAtLogin)
        NotificationCenter.default.post(name: .scanflowMenuBarSettingChanged, object: nil)
        #endif
    }

    #if os(macOS)
    func generateRemotePairingToken() {
        remoteScanPairingToken = Self.generatePairingToken()
    }

    func copyRemotePairingTokenToClipboard() {
        let token = remoteScanPairingToken
        guard !token.isEmpty else {
            showAlert(message: "Pairing token is empty")
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(token, forType: .string)
    }
    #endif

    private func isRemoteScanAuthorized(_ request: RemoteScanRequest) -> Bool {
        guard remoteScanRequirePairingToken else {
            return true
        }
        let expected = remoteScanPairingToken.trimmingCharacters(in: .whitespacesAndNewlines)
        let provided = request.pairingToken?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !expected.isEmpty else {
            return false
        }
        return expected == provided
    }

    private static func generatePairingToken() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        var token = ""
        for index in 0..<16 {
            if index == 4 || index == 8 || index == 12 {
                token.append("-")
            }
            token.append(alphabet.randomElement() ?? "A")
        }
        return token
    }

    func enterBackgroundMode() {
        #if os(macOS)
        isBackgroundModeEnabled = true
        if keepConnectedInBackground {
            scannerManager.startBrowsing()
        }
        NSApp.setActivationPolicy(.accessory)
        NSApp.hide(nil)
        #endif
    }

    func exitBackgroundMode() {
        #if os(macOS)
        isBackgroundModeEnabled = false
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        #endif
    }

    #if os(macOS)
    func updateLoginItemRegistration(enabled: Bool) {
        guard #available(macOS 13.0, *) else { return }
        do {
            let service = SMAppService.mainApp
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            logger.error("Failed to update login item: \(error.localizedDescription)")
        }
    }

    func handleKeepConnectedToggle(_ enabled: Bool) {
        if enabled && !startAtLogin {
            startAtLogin = true
        }
        if enabled {
            scannerManager.startBrowsing()
        }
        updateLoginItemRegistration(enabled: startAtLogin)
        NotificationCenter.default.post(
            name: .scanflowKeepConnectedChanged,
            object: nil,
            userInfo: ["enabled": enabled]
        )
    }

    func handleStartAtLoginToggle(_ enabled: Bool) {
        startAtLogin = enabled
        updateLoginItemRegistration(enabled: enabled)
    }

    func handleRemoteScanServerToggle(_ enabled: Bool) {
        remoteScanServerEnabled = enabled
        if enabled {
            remoteScanServer.start()
        } else {
            remoteScanServer.stop()
        }
    }

    func isAutoStartEnabled(for scanner: ICScannerDevice) -> Bool {
        autoStartScannerIDs.contains(scanner.scanflowIdentifier)
    }

    func setAutoStartEnabled(_ enabled: Bool, for scanner: ICScannerDevice) {
        var updated = autoStartScannerIDs
        let identifier = scanner.scanflowIdentifier
        if enabled {
            updated.insert(identifier)
        } else {
            updated.remove(identifier)
        }
        autoStartScannerIDs = updated
    }

    private func handleScannerDiscovered(_ scanner: ICScannerDevice) {
        guard keepConnectedInBackground, autoStartScanWhenReady else { return }
        guard autoStartScannerIDs.contains(scanner.scanflowIdentifier) else { return }
        if scannerManager.connectionState.isConnected { return }

        Task {
            try? await scannerManager.connect(to: scanner)
        }
    }
    #endif

#if os(macOS)
    private func handleScannerReadyForAutoScan(device: ICDevice?) {
        guard keepConnectedInBackground, autoStartScanWhenReady, currentPreset.scanOnDocumentPlacement else { return }
        guard !isScanning else { return }

        if let scanner = device as? ICScannerDevice {
            let identifier = scanner.scanflowIdentifier
            guard autoStartScannerIDs.contains(identifier) else { return }
        } else if device != nil {
            return
        }

        if scanQueue.isEmpty {
            addToQueue(preset: currentPreset, count: 1)
        }

        Task {
            await startScanning()
        }
    }
    #endif
}

private extension JSONEncoder {
    static var prettyPrinted: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
