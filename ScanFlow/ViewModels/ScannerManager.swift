//
//  ScannerManager.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

import Foundation
import os.log
#if os(macOS)
@preconcurrency import ImageCaptureCore
import AppKit
#endif

/// Logging subsystem for ScanFlow scanner operations
private let logger = Logger(subsystem: "com.scanflow.app", category: "ScannerManager")

public enum ConnectionState: Equatable {
    case disconnected
    case discovering
    case connecting
    case connected
    case scanning
    case error(String)

    public var description: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .discovering: return "Discovering..."
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .scanning: return "Scanning..."
        case .error(let message): return "Error: \(message)"
        }
    }

    public var isConnected: Bool {
        if case .connected = self { return true }
        if case .scanning = self { return true }
        return false
    }
}

struct ScanResult {
    #if os(macOS)
    let images: [NSImage]  // Multiple pages for ADF scanning
    var image: NSImage { images.first ?? NSImage() }  // Backwards compatible
    #else
    let imageData: Data
    #endif
    let metadata: ScanMetadata
}

@MainActor
protocol ScanExecuting: AnyObject {
    func scan(with preset: ScanPreset) async throws -> ScanResult
}

@Observable
@MainActor
public class ScannerManager: NSObject {
    // Runtime-tunable values surfaced in Advanced settings.
    var discoveryTimeoutSeconds: Int = 3
    var scanTimeoutSeconds: Int = 300
    var preserveTemporaryScanFiles: Bool = false
    var maxBufferedPages: Int = 200

    #if os(macOS)
    public var availableScanners: [ICScannerDevice] = []
    public var selectedScanner: ICScannerDevice?
    private var deviceBrowser: ICDeviceBrowser?
    #endif

    public var connectionState: ConnectionState = .disconnected
    public var lastError: String?
    public var isScanning: Bool = false
    var availableSources: [ScanSource] = ScanSource.allCases // Default to all, updated when connected
    #if os(macOS)
    var onDeviceReady: ((ICDevice?) -> Void)?
    var onScannerDiscovered: ((ICScannerDevice) -> Void)?
    #endif

    // Mock data for initial testing
    public var mockScannerName: String = "Epson FastFoto FF-680W"
    public var useMockScanner: Bool = false

    public override init() {
        super.init()
        #if os(macOS)
        setupDeviceBrowser()
        #endif
    }

    #if os(macOS)
    var temporaryScanDirectoryURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("ScanFlow", isDirectory: true)
    }
    #endif

    #if os(macOS)
    private func setupDeviceBrowser() {
        logger.info("Setting up device browser for scanner discovery")

        deviceBrowser = ICDeviceBrowser()
        deviceBrowser?.delegate = self

        // Include all scanner location types: local (USB), shared (network), bonjour, bluetooth
        // The mask combines device type with location types
        let scannerTypeMask = ICDeviceTypeMask.scanner.rawValue
        let localMask = ICDeviceLocationTypeMask.local.rawValue
        let sharedMask = ICDeviceLocationTypeMask.shared.rawValue
        let bonjourMask = ICDeviceLocationTypeMask.bonjour.rawValue
        let bluetoothMask = ICDeviceLocationTypeMask.bluetooth.rawValue

        let combinedMask = scannerTypeMask | localMask | sharedMask | bonjourMask | bluetoothMask
        logger.debug("Combined device mask: \(combinedMask) (scanner=\(scannerTypeMask), local=\(localMask), shared=\(sharedMask), bonjour=\(bonjourMask), bluetooth=\(bluetoothMask))")

        if let mask = ICDeviceTypeMask(rawValue: combinedMask) {
            deviceBrowser?.browsedDeviceTypeMask = mask
            logger.debug("Device browser mask set successfully")
        } else {
            logger.error("Failed to create device type mask")
        }

        logger.debug("Device browser delegate configured: \(self.deviceBrowser?.delegate != nil)")
        logger.info("Device browser configured for local, shared, bonjour, and bluetooth scanners (mask: \(combinedMask))")
    }

    public func discoverScanners() async {
        logger.info("Starting scanner discovery")

        // Only change to discovering state if we're not already connected
        if !connectionState.isConnected {
            connectionState = .discovering
        }

        // Ensure device browser is set up
        if deviceBrowser == nil {
            logger.warning("Device browser was nil, setting up again")
            setupDeviceBrowser()
        }

        // Start browsing if not already
        let isBrowsing = deviceBrowser?.isBrowsing ?? false
        if !isBrowsing {
            logger.debug("Starting device browser")
            deviceBrowser?.start()
        } else {
            logger.debug("Device browser already running")
        }

        // Wait for discovery - delegates will populate the list
        let timeout = max(1, discoveryTimeoutSeconds)
        logger.debug("Waiting \(timeout) seconds for scanner discovery")
        try? await Task.sleep(for: .seconds(timeout))

        // Log results
        logger.info("Discovery complete. Found \(self.availableScanners.count) scanner(s)")

        for scanner in availableScanners {
            logger.debug("Available scanner: \(scanner.name ?? "Unknown")")
        }

        // Only set to disconnected if we're still in discovering state
        if case .discovering = connectionState {
            connectionState = .disconnected
        }
    }

    /// Start continuous browsing - call once at app launch
    public func startBrowsing() {
        logger.debug("startBrowsing called")
        if deviceBrowser == nil {
            setupDeviceBrowser()
        }
        if !(deviceBrowser?.isBrowsing ?? false) {
            logger.debug("Starting device browser")
            deviceBrowser?.start()
            logger.debug("Device browser started, isBrowsing: \(self.deviceBrowser?.isBrowsing ?? false)")
        }
    }

    /// Stop browsing
    func stopBrowsing() {
        logger.debug("stopBrowsing called")
        deviceBrowser?.stop()
    }

    public func connect(to scanner: ICScannerDevice) async throws {
        let scannerType = scanner.usbLocationID != 0 ? "USB" : "Network"
        logger.info("Connecting to scanner: \(scanner.name ?? "Unknown") (type: \(scannerType))")
        connectionState = .connecting
        selectedScanner = scanner

        scanner.delegate = self

        logger.debug("Scanner hasOpenSession: \(scanner.hasOpenSession)")

        // If already has open session, we're good
        if scanner.hasOpenSession {
            logger.info("Scanner already has open session")
            connectionState = .connected
            return
        }

        logger.info("Requesting open session")

        // Try up to 3 times with delays
        var lastError: Error?
        for attempt in 1...3 {
            logger.debug("Connection attempt \(attempt)/3")

            do {
                // Use continuation with timeout to properly wait for the delegate callback
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask { @MainActor in
                        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                            // Set continuation BEFORE requesting session
                            self.connectionContinuation = continuation
                            logger.debug("Continuation set, calling requestOpenSession")
                            // Request open session - the result comes via delegate callback
                            scanner.requestOpenSession()
                        }
                    }

                    group.addTask {
                        // Timeout after 15 seconds
                        try await Task.sleep(for: .seconds(15))
                        throw ScannerError.connectionFailed
                    }

                    // Wait for either connection success or timeout
                    try await group.next()
                    group.cancelAll()
                }

                logger.info("Successfully connected on attempt \(attempt)")
                connectionState = .connected
                // Update available sources based on scanner capabilities
                updateAvailableSources()
                return

            } catch {
                logger.warning("Connection attempt \(attempt) failed: \(error.localizedDescription)")
                lastError = error
                connectionContinuation = nil

                if attempt < 3 {
                    logger.debug("Waiting 3 seconds before retry")
                    try? await Task.sleep(for: .seconds(3))
                }
            }
        }

        // All attempts failed
        logger.error("All connection attempts failed: \(lastError?.localizedDescription ?? "unknown error")")
        connectionState = .error(lastError?.localizedDescription ?? "Connection failed")
        selectedScanner = nil
        throw lastError ?? ScannerError.connectionFailed
    }

    func connectMockScanner() async {
        logger.info("Connecting to mock scanner...")
        connectionState = .connecting
        try? await Task.sleep(for: .seconds(1))
        connectionState = .connected
        availableSources = ScanSource.allCases // Mock scanner supports all
        logger.info("Mock scanner connected")
    }

    /// The preferred source to default to when connecting (flatbed if available)
    var preferredDefaultSource: ScanSource {
        if availableSources.contains(.flatbed) {
            return .flatbed
        }
        return availableSources.first ?? .flatbed
    }

    /// Updates availableSources based on the connected scanner's capabilities
    func updateAvailableSources() {
        guard let scanner = selectedScanner else {
            availableSources = ScanSource.allCases
            return
        }

        var sources: [ScanSource] = []
        let unitTypes = scanner.availableFunctionalUnitTypes

        logger.debug("Scanner functional units: \(unitTypes)")

        // Check for flatbed - always put first if available (preferred default)
        if unitTypes.contains(NSNumber(value: ICScannerFunctionalUnitType.flatbed.rawValue)) {
            sources.append(.flatbed)
            logger.debug("Flatbed available (preferred default)")
        }

        // Check for document feeder
        if unitTypes.contains(NSNumber(value: ICScannerFunctionalUnitType.documentFeeder.rawValue)) {
            sources.append(.adfFront)
            // Check if duplex is supported by selecting the unit temporarily
            if let fu = scanner.selectedFunctionalUnit as? ICScannerFunctionalUnitDocumentFeeder,
               fu.supportsDuplexScanning {
                sources.append(.adfDuplex)
                logger.debug("ADF with duplex available")
            } else {
                logger.debug("ADF (simplex only) available")
            }
        }

        // If no sources found, default to all (fallback)
        if sources.isEmpty {
            logger.warning("No functional units detected, defaulting to all sources")
            sources = ScanSource.allCases
        }

        availableSources = sources
        logger.debug("Available sources: \(sources.map { $0.rawValue })")
    }

    public func disconnect() async {
        if let scanner = selectedScanner {
            try? await scanner.requestCloseSession()
        }
        selectedScanner = nil
        connectionState = .disconnected
    }

    func scan(with preset: ScanPreset) async throws -> ScanResult {
        logger.info("Starting scan with preset: \(preset.name)")

        guard connectionState.isConnected || useMockScanner else {
            logger.error("Scan requested but not connected")
            throw ScannerError.notConnected
        }

        connectionState = .scanning
        isScanning = true

        defer {
            isScanning = false
            if case .error = connectionState {
                // Preserve error state
            } else {
                connectionState = selectedScanner == nil ? .disconnected : .connected
            }
        }

        // Use mock scanner if enabled
        if useMockScanner {
            logger.debug("Using mock scanner")
            try await Task.sleep(for: .seconds(3))
            let mockImage = createMockImage()
            let metadata = ScanMetadata(
                resolution: preset.resolution,
                colorSpace: "sRGB",
                timestamp: Date(),
                scannerModel: mockScannerName,
                width: Int(mockImage.size.width),
                height: Int(mockImage.size.height),
                bitDepth: 8
            )
            // Mock multi-page for ADF
            let pageCount = preset.source == .flatbed ? 1 : 3
            return ScanResult(images: Array(repeating: mockImage, count: pageCount), metadata: metadata)
        }

        // Real scanner workflow
        guard let scanner = selectedScanner else {
            logger.error("No scanner selected")
            throw ScannerError.notConnected
        }

        logger.debug("Scanner: \(scanner.name ?? "Unknown"), hasOpenSession: \(scanner.hasOpenSession)")

        // Ensure session is open
        if !scanner.hasOpenSession {
            logger.warning("Session not open, reconnecting")
            try await connect(to: scanner)
        }

        // Set up transfer mode - file-based to get scanned images as files
        scanner.transferMode = .fileBased
        logger.debug("Transfer mode set to file-based")

        // Set downloads directory
        let tempDir = temporaryScanDirectoryURL
        do {
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        } catch {
            logger.warning("Failed to create temp directory: \(error.localizedDescription)")
        }
        scanner.downloadsDirectory = tempDir
        logger.debug("Downloads directory: \(tempDir.path)")

        // Check available functional units
        logger.debug("Available functional units: \(scanner.availableFunctionalUnitTypes)")

        // Determine desired functional unit based on preset source
        let hasFlatbed = scanner.availableFunctionalUnitTypes.contains(NSNumber(value: ICScannerFunctionalUnitType.flatbed.rawValue))
        let hasDocumentFeeder = scanner.availableFunctionalUnitTypes.contains(NSNumber(value: ICScannerFunctionalUnitType.documentFeeder.rawValue))
        logger.debug("Scanner capabilities - Flatbed: \(hasFlatbed), Document Feeder: \(hasDocumentFeeder)")
        logger.debug("Preset source: \(preset.source.rawValue)")

        // Select the appropriate functional unit based on preset source
        var desiredUnitType: ICScannerFunctionalUnitType
        switch preset.source {
        case .flatbed:
            if hasFlatbed {
                desiredUnitType = .flatbed
            } else if hasDocumentFeeder {
                logger.warning("Flatbed requested but not available, falling back to document feeder")
                desiredUnitType = .documentFeeder
            } else {
                throw ScannerError.noFunctionalUnit
            }
        case .adfFront, .adfDuplex:
            if hasDocumentFeeder {
                desiredUnitType = .documentFeeder
            } else if hasFlatbed {
                logger.warning("Document feeder requested but not available, falling back to flatbed")
                desiredUnitType = .flatbed
            } else {
                throw ScannerError.noFunctionalUnit
            }
        }
        logger.debug("Requesting functional unit type: \(desiredUnitType.rawValue)")

        // Get functional unit - wait for it to be ready
        var selectedUnit = scanner.selectedFunctionalUnit
        logger.debug("Initial functional unit type: \(selectedUnit.type.rawValue)")

        // Select the desired unit if it's different from current
        if selectedUnit.type != desiredUnitType || selectedUnit.supportedResolutions.isEmpty {
            logger.debug("Selecting functional unit: \(desiredUnitType.rawValue)")
            scanner.requestSelect(desiredUnitType)

            // Wait for selection with polling
            for attempt in 1...10 {
                try await Task.sleep(for: .milliseconds(500))
                selectedUnit = scanner.selectedFunctionalUnit
                logger.debug("Selection attempt \(attempt): type=\(selectedUnit.type.rawValue), resolutions=\(selectedUnit.supportedResolutions)")
                if selectedUnit.type == desiredUnitType && !selectedUnit.supportedResolutions.isEmpty {
                    break
                }
            }

            if selectedUnit.supportedResolutions.isEmpty {
                logger.error("No valid functional unit after selection")
                throw ScannerError.noFunctionalUnit
            }
        }
        logger.debug("Functional unit type: \(selectedUnit.type.rawValue)")
        logger.debug("Supported resolutions: \(selectedUnit.supportedResolutions)")

        // Apply preset settings to scanner
        configureScannerSettings(selectedUnit, with: preset)

        // Wait a moment for settings to apply
        try await Task.sleep(for: .milliseconds(200))

        logger.info("Requesting scan from scanner")

        // Prepare for multi-page scan if using document feeder
        isMultiPageScan = preset.source != .flatbed
        scannedPages = []

        // Perform the scan with timeout
        let timeoutSeconds = max(30, scanTimeoutSeconds)
        return try await withThrowingTaskGroup(of: ScanResult.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ScanResult, Error>) in
                    Task { @MainActor in
                        self.currentScanContinuation = continuation
                        scanner.requestScan()
                        logger.debug("requestScan() called, waiting for delegate callback (multiPage: \(self.isMultiPageScan))")
                    }
                }
            }

            group.addTask {
                try await Task.sleep(for: .seconds(timeoutSeconds))
                throw ScannerError.scanTimeout
            }

            // Wait for first result (either scan or timeout)
            guard let result = try await group.next() else {
                throw ScannerError.scanFailed
            }
            group.cancelAll()
            return result
        }
    }

    private func configureScannerSettings(_ functionalUnit: ICScannerFunctionalUnit, with preset: ScanPreset) {
        logger.debug("Configuring scanner settings")
        logger.debug("Supported resolutions: \(functionalUnit.supportedResolutions)")
        logger.debug("Supported bit depths: \(functionalUnit.supportedBitDepths)")
        logger.debug("Physical size: \(functionalUnit.physicalSize.width)x\(functionalUnit.physicalSize.height)")

        // Set resolution - use supported resolution closest to preset
        let supportedResolutions = Array(functionalUnit.supportedResolutions)
        if supportedResolutions.contains(preset.resolution) {
            functionalUnit.resolution = preset.resolution
            logger.debug("Using preset resolution: \(preset.resolution) DPI")
        } else if !supportedResolutions.isEmpty {
            let closestResolution = supportedResolutions.min(by: { abs($0 - preset.resolution) < abs($1 - preset.resolution) }) ?? supportedResolutions[0]
            functionalUnit.resolution = closestResolution
            logger.debug("Preset resolution \(preset.resolution) not supported, using \(closestResolution) DPI")
        } else {
            logger.warning("No supported resolutions found, using default")
        }

        // Set bit depth based on preset
        let supportedBitDepths = Array(functionalUnit.supportedBitDepths)
        let desiredBitDepth = preset.bitDepth.rawValue
        if supportedBitDepths.contains(desiredBitDepth) {
            functionalUnit.bitDepth = ICScannerBitDepth(rawValue: UInt(desiredBitDepth)) ?? .depth8Bits
            logger.debug("Using bit depth: \(desiredBitDepth)-bit")
        } else if supportedBitDepths.contains(8) {
            functionalUnit.bitDepth = .depth8Bits
            logger.debug("Preset bit depth \(desiredBitDepth) not supported, using 8-bit")
        } else {
            logger.warning("No supported bit depths found")
        }

        // Set pixel data type based on preset colorMode
        logger.debug("Preset color mode: \(preset.colorMode.rawValue)")
        switch preset.colorMode {
        case .color:
            functionalUnit.pixelDataType = .RGB
            logger.debug("Set pixel type to RGB (Color)")
        case .grayscale:
            functionalUnit.pixelDataType = .gray
            logger.debug("Set pixel type to Gray")
        case .blackWhite:
            functionalUnit.pixelDataType = .BW
            logger.debug("Set pixel type to B&W")
        }

        // Set scan area - either custom or full physical size
        let physicalSize = functionalUnit.physicalSize
        if preset.useCustomScanArea && physicalSize.width > 0 && physicalSize.height > 0 {
            // Convert from preset's measurement unit to scanner's native unit (typically inches)
            var x = preset.scanAreaX
            var y = preset.scanAreaY
            var width = preset.scanAreaWidth
            var height = preset.scanAreaHeight

            // Convert to inches if needed (ICC uses inches internally)
            switch preset.measurementUnit {
            case .centimeters:
                x /= 2.54
                y /= 2.54
                width /= 2.54
                height /= 2.54
            case .pixels:
                // Convert pixels to inches using resolution
                let dpi = Double(preset.resolution)
                x /= dpi
                y /= dpi
                width /= dpi
                height /= dpi
            case .inches:
                break // Already in inches
            }

            // Clamp to physical size
            x = min(max(0, x), Double(physicalSize.width))
            y = min(max(0, y), Double(physicalSize.height))
            width = min(width, Double(physicalSize.width) - x)
            height = min(height, Double(physicalSize.height) - y)

            let scanRect = NSRect(x: x, y: y, width: width, height: height)
            functionalUnit.scanArea = scanRect
            logger.debug("Custom scan area set to: x=\(scanRect.origin.x), y=\(scanRect.origin.y), w=\(scanRect.width), h=\(scanRect.height)")
        } else if physicalSize.width > 0 && physicalSize.height > 0 {
            functionalUnit.scanArea = NSRect(origin: .zero, size: physicalSize)
            logger.debug("Scan area set to full size: \(functionalUnit.scanArea.width)x\(functionalUnit.scanArea.height)")
        } else {
            logger.warning("Invalid physical size, using default scan area")
        }

        // Configure document feeder if available
        if let documentFeeder = functionalUnit as? ICScannerFunctionalUnitDocumentFeeder {
            logger.debug("Configuring document feeder")
            documentFeeder.documentType = .typeDefault

            // Enable duplex if requested and supported
            let wantsDuplex = preset.source == .adfDuplex || preset.useDuplex
            logger.debug("Duplex support: \(documentFeeder.supportsDuplexScanning)")
            if wantsDuplex && documentFeeder.supportsDuplexScanning {
                documentFeeder.duplexScanningEnabled = true
                logger.debug("Duplex scanning enabled")
            } else {
                documentFeeder.duplexScanningEnabled = false
                logger.debug("Duplex scanning disabled")
            }

            // Set page orientation for odd pages using EXIF orientation values
            switch preset.oddPageOrientation {
            case .normal:
                documentFeeder.oddPageOrientation = .orientation1  // Normal
            case .rotated90:
                documentFeeder.oddPageOrientation = .orientation8  // 90 CW
            case .rotated180:
                documentFeeder.oddPageOrientation = .orientation3  // 180
            case .rotated270:
                documentFeeder.oddPageOrientation = .orientation6  // 90 CCW
            }
            logger.debug("Odd page orientation: \(preset.oddPageOrientation.displayName)")

            // Set page orientation for even pages (duplex only)
            if documentFeeder.duplexScanningEnabled {
                switch preset.evenPageOrientation {
                case .normal:
                    documentFeeder.evenPageOrientation = .orientation1
                case .rotated90:
                    documentFeeder.evenPageOrientation = .orientation8
                case .rotated180:
                    documentFeeder.evenPageOrientation = .orientation3
                case .rotated270:
                    documentFeeder.evenPageOrientation = .orientation6
                }
                logger.debug("Even page orientation: \(preset.evenPageOrientation.displayName)")
            }

            // Note: reverseFeederPageOrder is read-only in ICC
            logger.debug("Reverse page order preference: \(preset.reverseFeederPageOrder) (read-only in ICC)")
        }

        // Configure flatbed-specific settings
        if let flatbed = functionalUnit as? ICScannerFunctionalUnitFlatbed {
            logger.debug("Configuring flatbed")
            flatbed.documentType = .typeDefault
        }

        logger.debug("Final configuration - resolution: \(functionalUnit.resolution), pixelType: \(functionalUnit.pixelDataType.rawValue), bitDepth: \(functionalUnit.bitDepth.rawValue)")
    }

    // Store continuation for async scanning
    private var currentScanContinuation: CheckedContinuation<ScanResult, Error>?

    // Store continuation for async connection
    private var connectionContinuation: CheckedContinuation<Void, Error>?

    // Store scanned pages for multi-page ADF scanning
    private var scannedPages: [NSImage] = []
    private var isMultiPageScan: Bool = false

    public func requestOverviewScan() async throws -> NSImage {
        guard connectionState.isConnected || useMockScanner else {
            throw ScannerError.notConnected
        }

        // Simulate preview scan
        try await Task.sleep(for: .seconds(1))
        return createMockImage()
    }

    private func createMockImage() -> NSImage {
        // Create a simple colored rectangle as mock scan
        let size = NSSize(width: 1200, height: 1600)
        return NSImage(size: size, flipped: false) { rect in
            NSColor(red: 0.95, green: 0.95, blue: 0.92, alpha: 1.0).setFill()
            rect.fill()
            return true
        }
    }
    #else
    // iOS implementation stubs
    public func discoverScanners() async {
        connectionState = .error("Scanner discovery not supported on iOS")
    }

    func connectMockScanner() async {
        connectionState = .connecting
        try? await Task.sleep(for: .seconds(1))
        connectionState = .connected
    }

    public func disconnect() async {
        connectionState = .disconnected
    }

    var preferredDefaultSource: ScanSource {
        if availableSources.contains(.flatbed) {
            return .flatbed
        }
        return availableSources.first ?? .flatbed
    }

    func scan(with preset: ScanPreset) async throws -> ScanResult {
        _ = preset
        throw ScannerError.scanFailed
    }
    #endif
}

@MainActor
extension ScannerManager: ScanExecuting {}

#if os(macOS)
// MARK: - ICDeviceBrowserDelegate
extension ScannerManager: ICDeviceBrowserDelegate {
    nonisolated public func deviceBrowser(_ browser: ICDeviceBrowser, didAdd device: ICDevice, moreComing: Bool) {
        let deviceType = device is ICScannerDevice ? "SCANNER" : "OTHER"
        let locationDesc = device.usbLocationID != 0 ? "USB" : "Network/Shared"

        logger.debug("Device found: \(device.name ?? "Unknown") | Type: \(deviceType) | Location: \(locationDesc) | moreComing: \(moreComing)")

        if let scanner = device as? ICScannerDevice {
            Task { @MainActor in
                logger.info("Scanner found: \(scanner.name ?? "Unknown"), location: \(locationDesc)")
                if !self.availableScanners.contains(scanner) {
                    self.availableScanners.append(scanner)
                }
                self.onScannerDiscovered?(scanner)
                if !moreComing {
                    logger.info("Scanner discovery batch complete, found \(self.availableScanners.count) scanner(s)")
                    if case .discovering = self.connectionState {
                        self.connectionState = .disconnected
                    }
                }
            }
        } else {
            logger.debug("Device is not a scanner: \(device.name ?? "Unknown")")
        }
    }

    nonisolated public func deviceBrowser(_ browser: ICDeviceBrowser, didRemove device: ICDevice, moreGoing: Bool) {
        logger.debug("Device removed: \(device.name ?? "Unknown")")
        if let scanner = device as? ICScannerDevice {
            Task { @MainActor in
                logger.info("Scanner removed: \(scanner.name ?? "Unknown")")
                self.availableScanners.removeAll { $0 == scanner }
            }
        }
    }

    nonisolated public func deviceBrowser(_ browser: ICDeviceBrowser, didEncounterError error: Error) {
        logger.error("Device browser error: \(error.localizedDescription)")
        Task { @MainActor in
            self.connectionState = .error(error.localizedDescription)
            self.lastError = error.localizedDescription
        }
    }

    nonisolated public func deviceBrowserDidEnumerateLocalDevices(_ browser: ICDeviceBrowser) {
        logger.debug("Finished enumerating local devices")
    }
}

// MARK: - ICScannerDeviceDelegate
extension ScannerManager: ICScannerDeviceDelegate {
    nonisolated public func didRemove(_ device: ICDevice) {
        if let scanner = device as? ICScannerDevice {
            Task { @MainActor in
                if scanner == selectedScanner {
                    logger.info("Selected scanner was removed")
                    selectedScanner = nil
                    connectionState = .disconnected
                }
            }
        }
    }

    nonisolated public func device(_ device: ICDevice, didOpenSessionWithError error: Error?) {
        logger.debug("didOpenSessionWithError called, error: \(error?.localizedDescription ?? "none")")
        // Resume the connection continuation synchronously to avoid deadlocks
        DispatchQueue.main.async {
            if let continuation = self.connectionContinuation {
                self.connectionContinuation = nil
                if let error = error {
                    logger.error("Session open failed: \(error.localizedDescription)")
                    self.connectionState = .error(error.localizedDescription)
                    self.lastError = error.localizedDescription
                    continuation.resume(throwing: error)
                } else {
                    logger.info("Session opened successfully")
                    self.connectionState = .connected
                    continuation.resume()
                }
            } else {
                logger.debug("No connection continuation found, updating state directly")
                guard case .connecting = self.connectionState else { return }
                if let error = error {
                    self.connectionState = .error(error.localizedDescription)
                    self.lastError = error.localizedDescription
                } else {
                    self.connectionState = .connected
                }
            }
        }
    }

    nonisolated public func device(_ device: ICDevice, didCloseSessionWithError error: Error?) {
        logger.debug("Session closed, error: \(error?.localizedDescription ?? "none")")
        Task { @MainActor in
            connectionState = .disconnected
            selectedScanner = nil
        }
    }

    nonisolated public func scannerDevice(_ scanner: ICScannerDevice, didSelect functionalUnit: ICScannerFunctionalUnit, error: Error?) {
        logger.debug("didSelect functionalUnit: \(functionalUnit.type.rawValue), error: \(error?.localizedDescription ?? "none")")
        if let error = error {
            Task { @MainActor in
                lastError = error.localizedDescription
            }
        }
    }

    nonisolated public func scannerDevice(_ scanner: ICScannerDevice, didScanTo url: URL) {
        logger.debug("didScanTo URL: \(url.path)")
        
        // Capture scanner properties before the async closure to avoid Sendable warnings
        let scannerResolution = scanner.selectedFunctionalUnit.resolution
        let scannerName = scanner.name ?? "Unknown Scanner"
        let scannerBitDepth = scanner.selectedFunctionalUnit.pixelDataType == .BW ? 1 : 8
        
        // Image was scanned successfully - use DispatchQueue to avoid deadlocks
        DispatchQueue.main.async {
            logger.debug("Loading image from: \(url.path)")
            guard let image = NSImage(contentsOf: url) else {
                logger.error("Failed to load image from URL")
                if let continuation = self.currentScanContinuation {
                    self.currentScanContinuation = nil
                    continuation.resume(throwing: ScannerError.scanFailed)
                }
                return
            }

            logger.debug("Image loaded, size: \(image.size.width)x\(image.size.height)")

            // For multi-page scanning (ADF), collect pages until scan completes
            if self.isMultiPageScan {
                if self.scannedPages.count >= self.maxBufferedPages {
                    logger.error("Exceeded buffered page limit (\(self.maxBufferedPages)). Failing scan to prevent excessive memory use.")
                    if let continuation = self.currentScanContinuation {
                        self.currentScanContinuation = nil
                        continuation.resume(throwing: ScannerError.scanFailed)
                    }
                    self.scannedPages = []
                    self.isMultiPageScan = false
                    return
                }
                self.scannedPages.append(image)
                logger.debug("Page \(self.scannedPages.count) collected, waiting for more pages")
                // Clean up temporary file
                if !self.preserveTemporaryScanFiles {
                    try? FileManager.default.removeItem(at: url)
                }
                // Don't resume continuation yet - wait for didCompleteScanWithError
            } else {
                // Single page scan (flatbed) - resume immediately
                guard let continuation = self.currentScanContinuation else {
                    logger.warning("No scan continuation to resume")
                    return
                }
                self.currentScanContinuation = nil

                let metadata = ScanMetadata(
                    resolution: scannerResolution,
                    colorSpace: "sRGB",
                    timestamp: Date(),
                    scannerModel: scannerName,
                    width: Int(image.size.width),
                    height: Int(image.size.height),
                    bitDepth: scannerBitDepth
                )

                let result = ScanResult(images: [image], metadata: metadata)
                logger.info("Single-page scan completed successfully")
                continuation.resume(returning: result)

                // Clean up temporary file
                if !self.preserveTemporaryScanFiles {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
    }

    nonisolated public func scannerDevice(_ scanner: ICScannerDevice, didCompleteOverviewScanWithError error: Error?) {
        logger.debug("didCompleteOverviewScanWithError: \(error?.localizedDescription ?? "none")")
        if let error = error {
            Task { @MainActor in
                lastError = error.localizedDescription
            }
        }
    }

    nonisolated public func scannerDevice(_ scanner: ICScannerDevice, didCompleteScanWithError error: Error?) {
        if let error = error {
            let nsError = error as NSError
            logger.error("Scan completed with error: \(error.localizedDescription) (domain: \(nsError.domain), code: \(nsError.code))")
        } else {
            logger.debug("Scan completed without error")
        }

        // Capture scanner properties before the async closure to avoid Sendable warnings
        let scannerResolution = scanner.selectedFunctionalUnit.resolution
        let scannerName = scanner.name ?? "Unknown Scanner"
        let scannerBitDepth = scanner.selectedFunctionalUnit.pixelDataType == .BW ? 1 : 8

        DispatchQueue.main.async {
            logger.debug("Processing completion, pages collected: \(self.scannedPages.count)")

            guard let continuation = self.currentScanContinuation else {
                logger.debug("No scan continuation for completion (already handled by didScanTo)")
                return
            }
            self.currentScanContinuation = nil

            if let error = error {
                logger.error("Scan failed: \(error.localizedDescription)")
                self.lastError = error.localizedDescription
                self.scannedPages = []
                self.isMultiPageScan = false
                continuation.resume(throwing: error)
            } else if self.isMultiPageScan && !self.scannedPages.isEmpty {
                // Multi-page scan completed with pages - return all collected pages
                let pages = self.scannedPages
                logger.info("Multi-page scan completed with \(pages.count) page(s)")

                let firstImage = pages[0]
                let metadata = ScanMetadata(
                    resolution: scannerResolution,
                    colorSpace: "sRGB",
                    timestamp: Date(),
                    scannerModel: scannerName,
                    width: Int(firstImage.size.width),
                    height: Int(firstImage.size.height),
                    bitDepth: scannerBitDepth
                )

                let result = ScanResult(images: pages, metadata: metadata)
                self.scannedPages = []
                self.isMultiPageScan = false
                continuation.resume(returning: result)
            } else {
                // Single page scan without image received via didScanTo, or no pages collected
                logger.warning("Scan completed but no image(s) received")
                self.scannedPages = []
                self.isMultiPageScan = false
                continuation.resume(throwing: ScannerError.scanFailed)
            }
        }
    }

    // Progress tracking
    nonisolated public func scannerDevice(_ scanner: ICScannerDevice, didScanTo data: ICScannerBandData) {
        logger.debug("Scan data band: \(data.dataSize) bytes, fullImageWidth: \(data.fullImageWidth), fullImageHeight: \(data.fullImageHeight)")
    }

    // Status information delegate
    nonisolated public func device(_ device: ICDevice, didReceiveStatusInformation status: [ICDeviceStatus : Any]) {
        logger.debug("Status update received with \(status.count) entries")
    }

    // Error delegate
    nonisolated public func device(_ device: ICDevice, didEncounterError error: Error?) {
        logger.error("Device error: \(error?.localizedDescription ?? "unknown")")
        Task { @MainActor in
            if let error = error {
                lastError = error.localizedDescription
                // If we have a pending scan continuation, fail it
                if let continuation = currentScanContinuation {
                    currentScanContinuation = nil
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // Ready for scan
    nonisolated public func deviceDidBecomeReady(_ device: ICDevice) {
        logger.info("Device became ready: \(device.name ?? "Unknown")")
        Task { @MainActor in
            self.onDeviceReady?(device)
        }
    }
}
#endif

#if os(macOS)
extension ICScannerDevice {
    var scanflowIdentifier: String {
        let name = self.name ?? "Unknown"
        let transport = transportType ?? "unknown"
        return "\(name)|\(usbLocationID)|\(transport)"
    }
}
#endif

enum ScannerError: LocalizedError {
    case notConnected
    case connectionFailed
    case scanFailed
    case noScannersFound
    case noFunctionalUnit
    case scanTimeout
    case scanCancelled

    var errorDescription: String? {
        switch self {
        case .notConnected: return "Scanner is not connected"
        case .connectionFailed: return "Failed to connect to scanner"
        case .scanFailed: return "Scan operation failed"
        case .noScannersFound: return "No scanners found on network"
        case .noFunctionalUnit: return "Scanner has no functional unit available"
        case .scanTimeout: return "Scan timed out - scanner may be busy or disconnected"
        case .scanCancelled: return "Scan was cancelled"
        }
    }
}
