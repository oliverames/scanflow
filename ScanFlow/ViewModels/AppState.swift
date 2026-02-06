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

public enum NavigationSection: String, CaseIterable, Identifiable {
    case scan = "Scan"
    case queue = "Scan Queue"
    case library = "Scanned Files"
    case presets = "Scan Presets"

    public var id: String { rawValue }

    public var iconName: String {
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
    public var scannerManager = ScannerManager()
    #if os(macOS)
    public var imageProcessor: ImageProcessor
    public var documentActionService: DocumentActionService
    @ObservationIgnored public lazy var remoteScanServer: RemoteScanServer = RemoteScanServer(scanHandler: { [weak self] request in
        guard let self else {
            throw RemoteScanServer.ServerError.serverUnavailable
        }
        return try await self.performRemoteScan(request)
    })
    #else
    public var remoteScanClient: RemoteScanClient
    #endif
    public var scanQueue: [QueuedScan] = []
    public var scannedFiles: [ScannedFile] = []
    public var presets: [ScanPreset] = ScanPreset.defaults
    public var currentPreset: ScanPreset = ScanPreset.quickScan
    public var selectedSection: NavigationSection = .scan
    public var isScanning: Bool = false
    public var showingAlert: Bool = false
    public var alertMessage: String = ""
    public var showScanSettings: Bool = true
    public var showScannerSelection: Bool = false
    public var isBackgroundModeEnabled: Bool = false

    // Settings - use separate ObservableObject to avoid @Observable/@AppStorage conflict
    @ObservationIgnored private var _settings = SettingsStore()
    
    public var defaultResolution: Int {
        get { _settings.defaultResolution }
        set { _settings.defaultResolution = newValue }
    }
    public var defaultFormat: String {
        get { _settings.defaultFormat }
        set { _settings.defaultFormat = newValue }
    }
    public var scanDestination: String {
        get { _settings.scanDestination }
        set { _settings.scanDestination = newValue }
    }
    public var autoOpenDestination: Bool {
        get { _settings.autoOpenDestination }
        set { _settings.autoOpenDestination = newValue }
    }
    public var organizationPattern: String {
        get { _settings.organizationPattern }
        set { _settings.organizationPattern = newValue }
    }
    public var fileNamingTemplate: String {
        get { _settings.fileNamingTemplate }
        set { _settings.fileNamingTemplate = newValue }
    }
    public var useMockScanner: Bool {
        get { _settings.useMockScanner }
        set {
            _settings.useMockScanner = newValue
            scannerManager.useMockScanner = newValue
        }
    }

    public var keepConnectedInBackground: Bool {
        get { _settings.keepConnectedInBackground }
        set { _settings.keepConnectedInBackground = newValue }
    }

    public var shouldPromptForBackgroundConnection: Bool {
        get { _settings.shouldPromptForBackgroundConnection }
        set { _settings.shouldPromptForBackgroundConnection = newValue }
    }

    public var hasConnectedScanner: Bool {
        get { _settings.hasConnectedScanner }
        set { _settings.hasConnectedScanner = newValue }
    }

    public var autoStartScanWhenReady: Bool {
        get { _settings.autoStartScanWhenReady }
        set { _settings.autoStartScanWhenReady = newValue }
    }

    public var startAtLogin: Bool {
        get { _settings.startAtLogin }
        set { _settings.startAtLogin = newValue }
    }

    public var remoteScanServerEnabled: Bool {
        get { _settings.remoteScanServerEnabled }
        set { _settings.remoteScanServerEnabled = newValue }
    }

    public var autoStartScannerIDs: Set<String> {
        get { _settings.autoStartScannerIDs }
        set { _settings.autoStartScannerIDs = newValue }
    }

    public var menuBarAlwaysEnabled: Bool {
        get { _settings.menuBarAlwaysEnabled }
        set { _settings.menuBarAlwaysEnabled = newValue }
    }

    /// Tracks whether a scan was performed during this app session (not persisted)
    public var didScanThisSession: Bool = false

    // AI-assisted file naming settings (defaults for new presets)
    public var defaultNamingSettings: NamingSettings {
        get { _settings.defaultNamingSettings }
        set { _settings.defaultNamingSettings = newValue }
    }

    // Document separation settings (defaults for new presets)
    public var defaultSeparationSettings: SeparationSettings {
        get { _settings.defaultSeparationSettings }
        set { _settings.defaultSeparationSettings = newValue }
    }

    public init() {
        logger.info("AppState initializing...")
        #if os(macOS)
        let processor = ImageProcessor()
        imageProcessor = processor
        documentActionService = DocumentActionService(imageProcessor: processor)
        if remoteScanServerEnabled {
            remoteScanServer.start()
        }
        scannerManager.useMockScanner = useMockScanner
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

    public func loadPresets() {
        logger.info("Loading presets from UserDefaults")
        guard let data = UserDefaults.standard.data(forKey: "customPresets") else {
            logger.info("No custom presets found, using defaults")
            return
        }
        
        do {
            let customPresets = try JSONDecoder().decode([ScanPreset].self, from: data)
            presets = ScanPreset.defaults + customPresets
            logger.info("Loaded \(customPresets.count) custom presets")
        } catch {
            logger.error("Failed to decode custom presets: \(error.localizedDescription). Using defaults.")
            presets = ScanPreset.defaults
        }
    }

    public func savePresets() {
        let customPresets = presets.filter { preset in
            !ScanPreset.defaults.contains { $0.id == preset.id }
        }
        do {
            let data = try JSONEncoder().encode(customPresets)
            UserDefaults.standard.set(data, forKey: "customPresets")
            logger.info("Saved \(customPresets.count) custom presets")
        } catch {
            logger.error("Failed to encode presets: \(error.localizedDescription)")
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

    public func removeFromQueue(scan: QueuedScan) {
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

        for index in scanQueue.indices where scanQueue[index].status == .pending {
            logger.info("Processing queue item \(index + 1): \(self.scanQueue[index].name)")
            scanQueue[index].status = .scanning

            do {
                #if os(macOS)
                logger.info("Initiating scan with preset: \(self.scanQueue[index].preset.name)")
                let result = try await scannerManager.scan(with: scanQueue[index].preset)
                logger.info("Scan completed, processing image...")

                scanQueue[index].status = .processing
                let savedFiles = try await saveScannedImage(result, preset: scanQueue[index].preset)
                scannedFiles.append(contentsOf: savedFiles)
                if let firstFile = savedFiles.first {
                    logger.info("Image saved to: \(firstFile.fileURL.path)")
                }

                scanQueue[index].status = .completed
                didScanThisSession = true
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
    private func saveScannedImage(_ result: ScanResult, preset: ScanPreset) async throws -> [ScannedFile] {
        let destPath = NSString(string: preset.destination).expandingTildeInPath
        let destURL = URL(fileURLWithPath: destPath)

        do {
            try FileManager.default.createDirectory(at: destURL, withIntermediateDirectories: true)
        } catch {
            logger.error("Failed to create destination directory: \(error.localizedDescription)")
            throw error
        }

        let images = result.images
        let pageCount = images.count
        logger.info("Saving \(pageCount) page(s) to \(destURL.path)")

        var savedFiles: [ScannedFile] = []
        var sequenceCounter = preset.useSequenceNumber ? preset.sequenceStartNumber : 0

        func fallbackBaseName() -> String {
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

        for (documentIndex, documentPages) in documents.enumerated() {
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
                    guard let tiffData = image.tiffRepresentation,
                          let bitmapImage = NSBitmapImageRep(data: tiffData),
                          let imageData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: preset.quality]) else {
                        throw ScannerError.scanFailed
                    }
                    let filename = filenameForDocument(baseName: baseName, extensionString: extensionString, pageIndex: documentPages.count > 1 ? index : nil)
                    let targetURL = resolveDestinationURL(for: filename)
                    try imageData.write(to: targetURL)
                    try finalizeFile(url: targetURL, filename: targetURL.lastPathComponent)
                }

            case .png:
                for (index, image) in documentPages.enumerated() {
                    guard let tiffData = image.tiffRepresentation,
                          let bitmapImage = NSBitmapImageRep(data: tiffData),
                          let imageData = bitmapImage.representation(using: .png, properties: [:]) else {
                        throw ScannerError.scanFailed
                    }
                    let filename = filenameForDocument(baseName: baseName, extensionString: extensionString, pageIndex: documentPages.count > 1 ? index : nil)
                    let targetURL = resolveDestinationURL(for: filename)
                    try imageData.write(to: targetURL)
                    try finalizeFile(url: targetURL, filename: targetURL.lastPathComponent)
                }

            case .tiff:
                for (index, image) in documentPages.enumerated() {
                    guard let tiffData = image.tiffRepresentation else {
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
                    if let pdfPage = PDFPage(image: image) {
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
                    guard let tiffData = image.tiffRepresentation,
                          let bitmapImage = NSBitmapImageRep(data: tiffData),
                          let jpegData = bitmapImage.representation(using: .jpeg, properties: [.compressionFactor: preset.quality]),
                          let jpegImage = NSImage(data: jpegData),
                          let pdfPage = PDFPage(image: jpegImage) else {
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
        var documents: [[NSImage]] = [pages]
        if !forceSingleDocument {
            if preset.separationSettings.enabled {
                let separator = DocumentSeparator(imageProcessor: imageProcessor, barcodeRecognizer: BarcodeRecognizer())
                let separationResult = try await separator.separateDocuments(pages: pages, settings: preset.separationSettings)
                documents = separationResult.documents
            } else if preset.splitOnPage, pages.count > 1 {
                documents = splitPages(pages: pages, chunkSize: preset.splitPageNumber)
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

    private func remoteDocumentFilename(base: String, index: Int?) -> String {
        let sanitizedBase = sanitizeFilenameInput(base.isEmpty ? "Remote Scan" : base)
        if let index {
            return "\(sanitizedBase)-\(String(format: "%03d", index + 1)).pdf"
        }
        return "\(sanitizedBase).pdf"
    }

    private func createRemotePDFData(from pages: [NSImage], searchable: Bool) async throws -> Data {
        let pdfDocument = PDFDocument()

        for (index, image) in pages.enumerated() {
            if let pdfPage = PDFPage(image: image) {
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
        var candidate = fallback()

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
                    handleNamingFallback(error: error, settings: preset.namingSettings)
                }
            } else {
                handleNamingFallback(error: AIFileNamerError.modelUnavailable, settings: preset.namingSettings)
            }
        }

        if preset.editEachFilename, let previewImage = pages.first {
            let fallbackLabel = "Document \(documentIndex + 1)"
            let manualName = promptForFilename(suggested: candidate, preview: previewImage, fallbackLabel: fallbackLabel)
            if let manualName, !manualName.isEmpty {
                candidate = manualName
            }
        }

        return candidate
    }

    private func handleNamingFallback(error: Error, settings: NamingSettings) {
        switch settings.fallbackBehavior {
        case .promptManual:
            showAlert(message: "AI naming unavailable. Using the default naming pattern.")
        case .notifyAndFallback:
            showAlert(message: "AI naming failed (\(error.localizedDescription)). Using the default naming pattern.")
        case .silentFallback:
            break
        }
    }

    #if os(macOS)
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

    public func sanitizeFilenameInput(_ filename: String) -> String {
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

    public func showAlert(message: String) {
        alertMessage = message
        showingAlert = true
    }

    public func markScannerUsed() {
        hasConnectedScanner = true
    }

    public func enterBackgroundMode() {
        #if os(macOS)
        isBackgroundModeEnabled = true
        if keepConnectedInBackground {
            scannerManager.startBrowsing()
        }
        NSApp.setActivationPolicy(.accessory)
        NSApp.hide(nil)
        #endif
    }

    public func exitBackgroundMode() {
        #if os(macOS)
        isBackgroundModeEnabled = false
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        #endif
    }

    #if os(macOS)
    public func updateLoginItemRegistration(enabled: Bool) {
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

    public func handleKeepConnectedToggle(_ enabled: Bool) {
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

    public func handleStartAtLoginToggle(_ enabled: Bool) {
        startAtLogin = enabled
        updateLoginItemRegistration(enabled: enabled)
    }

    public func handleRemoteScanServerToggle(_ enabled: Bool) {
        remoteScanServerEnabled = enabled
        if enabled {
            remoteScanServer.start()
        } else {
            remoteScanServer.stop()
        }
    }

    public func isAutoStartEnabled(for scanner: ICScannerDevice) -> Bool {
        autoStartScannerIDs.contains(scanner.scanflowIdentifier)
    }

    public func setAutoStartEnabled(_ enabled: Bool, for scanner: ICScannerDevice) {
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
        guard keepConnectedInBackground, autoStartScanWhenReady else { return }
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
