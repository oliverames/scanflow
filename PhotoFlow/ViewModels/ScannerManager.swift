//
//  ScannerManager.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

import Foundation
import os.log
#if os(macOS)
import ImageCaptureCore
import AppKit
#endif

/// Logging subsystem for ScanFlow
private let logger = Logger(subsystem: "com.scanflow.app", category: "ScannerManager")

enum ConnectionState: Equatable {
    case disconnected
    case discovering
    case connecting
    case connected
    case scanning
    case error(String)

    var description: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .discovering: return "Discovering..."
        case .connecting: return "Connecting..."
        case .connected: return "Connected"
        case .scanning: return "Scanning..."
        case .error(let message): return "Error: \(message)"
        }
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        if case .scanning = self { return true }
        return false
    }
}

struct ScanResult {
    #if os(macOS)
    let image: NSImage
    #else
    let imageData: Data
    #endif
    let metadata: ScanMetadata
}

@Observable
@MainActor
class ScannerManager: NSObject {
    #if os(macOS)
    var availableScanners: [ICScannerDevice] = []
    var selectedScanner: ICScannerDevice?
    private var deviceBrowser: ICDeviceBrowser?
    #endif

    var connectionState: ConnectionState = .disconnected
    var lastError: String?
    var isScanning: Bool = false

    // Mock data for initial testing
    var mockScannerName: String = "Epson FastFoto FF-680W"
    var useMockScanner: Bool = false

    override init() {
        super.init()
        #if os(macOS)
        setupDeviceBrowser()
        #endif
    }

    #if os(macOS)
    private func setupDeviceBrowser() {
        print("🔧 [ScannerManager] Setting up device browser...")
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
        print("🔧 [ScannerManager] Combined device mask: \(combinedMask) (scanner=\(scannerTypeMask), local=\(localMask), shared=\(sharedMask), bonjour=\(bonjourMask), bluetooth=\(bluetoothMask))")

        if let mask = ICDeviceTypeMask(rawValue: combinedMask) {
            deviceBrowser?.browsedDeviceTypeMask = mask
            print("🔧 [ScannerManager] Device browser mask set successfully")
        } else {
            print("❌ [ScannerManager] Failed to create device type mask!")
        }

        print("🔧 [ScannerManager] Device browser delegate: \(String(describing: deviceBrowser?.delegate))")
        logger.info("Device browser configured for local, shared, bonjour, and bluetooth scanners (mask: \(combinedMask))")
    }

    func discoverScanners() async {
        print("🔍 [ScannerManager] discoverScanners() called")
        logger.info("Starting scanner discovery...")
        connectionState = .discovering

        // DON'T clear previous scanners - let the delegate manage the list
        // availableScanners.removeAll()

        // Ensure device browser is set up
        if deviceBrowser == nil {
            print("⚠️ [ScannerManager] Device browser was nil, setting up again")
            logger.warning("Device browser was nil, setting up again")
            setupDeviceBrowser()
        }

        let isBrowsing = deviceBrowser?.isBrowsing ?? false
        print("🔍 [ScannerManager] Device browser isBrowsing: \(isBrowsing)")

        // Only start if not already browsing
        if !isBrowsing {
            print("🔍 [ScannerManager] Calling deviceBrowser.start()...")
            deviceBrowser?.start()
            print("🔍 [ScannerManager] Device browser isBrowsing after start: \(deviceBrowser?.isBrowsing ?? false)")
        } else {
            print("🔍 [ScannerManager] Device browser already running")
        }

        logger.info("Device browser running...")

        // Wait for discovery
        print("🔍 [ScannerManager] Waiting 5 seconds for scanner discovery...")
        logger.info("Waiting 5 seconds for scanner discovery...")
        try? await Task.sleep(for: .seconds(5))

        // Update state based on results
        print("🔍 [ScannerManager] Discovery wait complete. Found \(self.availableScanners.count) scanner(s)")
        logger.info("Discovery complete. Found \(self.availableScanners.count) scanner(s)")

        if availableScanners.isEmpty {
            print("⚠️ [ScannerManager] No scanners found!")
            logger.warning("No scanners found")
        } else {
            for scanner in availableScanners {
                print("✅ [ScannerManager] Found scanner: \(scanner.name ?? "Unknown")")
                logger.info("Found scanner: \(scanner.name ?? "Unknown")")
            }
        }
        connectionState = .disconnected
    }

    /// Start continuous browsing - call once at app launch
    func startBrowsing() {
        print("🔍 [ScannerManager] startBrowsing() called")
        if deviceBrowser == nil {
            setupDeviceBrowser()
        }
        if !(deviceBrowser?.isBrowsing ?? false) {
            print("🔍 [ScannerManager] Starting device browser...")
            deviceBrowser?.start()
            print("🔍 [ScannerManager] Device browser started, isBrowsing: \(deviceBrowser?.isBrowsing ?? false)")
        }
    }

    /// Stop browsing
    func stopBrowsing() {
        print("🔍 [ScannerManager] stopBrowsing() called")
        deviceBrowser?.stop()
    }

    func connect(to scanner: ICScannerDevice) async throws {
        print("🔌 [ScannerManager] Connecting to scanner: \(scanner.name ?? "Unknown")")
        logger.info("Connecting to scanner: \(scanner.name ?? "Unknown")")
        connectionState = .connecting
        selectedScanner = scanner

        scanner.delegate = self

        print("🔌 [ScannerManager] Scanner hasOpenSession before: \(scanner.hasOpenSession)")
        print("🔌 [ScannerManager] Requesting open session...")
        logger.info("Requesting open session...")

        do {
            try await scanner.requestOpenSession()
            print("🔌 [ScannerManager] requestOpenSession() completed")
        } catch {
            print("❌ [ScannerManager] requestOpenSession() threw error: \(error)")
            logger.error("Open session error: \(error.localizedDescription)")
            connectionState = .error(error.localizedDescription)
            selectedScanner = nil
            throw error
        }

        // Wait for connection to establish
        print("🔌 [ScannerManager] Waiting for session to establish...")
        try await Task.sleep(for: .seconds(2))

        print("🔌 [ScannerManager] Scanner hasOpenSession after: \(scanner.hasOpenSession)")
        if scanner.hasOpenSession {
            print("✅ [ScannerManager] Successfully connected!")
            logger.info("Successfully connected to scanner")
            connectionState = .connected
        } else {
            print("❌ [ScannerManager] Session not open after request")
            logger.error("Failed to open scanner session - session not open")
            connectionState = .disconnected
            selectedScanner = nil
            throw ScannerError.connectionFailed
        }
    }

    func connectMockScanner() async {
        logger.info("Connecting to mock scanner...")
        connectionState = .connecting
        try? await Task.sleep(for: .seconds(1))
        connectionState = .connected
        logger.info("Mock scanner connected")
    }

    func disconnect() async {
        if let scanner = selectedScanner {
            try? await scanner.requestCloseSession()
        }
        selectedScanner = nil
        connectionState = .disconnected
    }

    func scan(with preset: ScanPreset) async throws -> ScanResult {
        guard connectionState.isConnected || useMockScanner else {
            throw ScannerError.notConnected
        }

        connectionState = .scanning
        isScanning = true

        defer {
            isScanning = false
            connectionState = .connected
        }

        // Use mock scanner if enabled
        if useMockScanner {
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
            return ScanResult(image: mockImage, metadata: metadata)
        }

        // Real scanner workflow
        guard let scanner = selectedScanner else {
            throw ScannerError.notConnected
        }

        // Configure scanner functional unit
        let functionalUnit = scanner.selectedFunctionalUnit
        guard functionalUnit != nil else {
            throw ScannerError.scanFailed
        }

        // Apply preset settings to scanner
        configureScannerSettings(functionalUnit, with: preset)

        // Perform the scan
        return try await withCheckedThrowingContinuation { continuation in
            currentScanContinuation = continuation
            scanner.requestScan()
        }
    }

    private func configureScannerSettings(_ functionalUnit: ICScannerFunctionalUnit, with preset: ScanPreset) {
        // Set resolution
        if functionalUnit.supportedResolutions.contains(preset.resolution) {
            functionalUnit.resolution = preset.resolution
        }

        // Configure document feeder if available
        if let documentFeeder = functionalUnit as? ICScannerFunctionalUnitDocumentFeeder {
            documentFeeder.documentType = .typeDefault

            // Enable duplex if requested and supported
            if preset.useDuplex && documentFeeder.supportsDuplexScanning {
                documentFeeder.duplexScanningEnabled = true
            } else {
                documentFeeder.duplexScanningEnabled = false
            }

            // Enable document feeder mode
            if preset.useADF {
                documentFeeder.documentType = .typeDefault
            }
        }

        // Set scan area to maximum
        let physicalSize = functionalUnit.physicalSize
        functionalUnit.scanArea = NSRect(origin: .zero, size: physicalSize)

        // Set pixel data type based on preset
        if preset.documentType == .document {
            functionalUnit.pixelDataType = .BW // Black & white for documents
        } else {
            functionalUnit.pixelDataType = .RGB // Color for photos
        }
    }

    // Store continuation for async scanning
    private var currentScanContinuation: CheckedContinuation<ScanResult, Error>?

    func requestOverviewScan() async throws -> NSImage {
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
    func discoverScanners() async {
        connectionState = .error("Scanner discovery not supported on iOS")
    }

    func connectMockScanner() async {
        connectionState = .connecting
        try? await Task.sleep(for: .seconds(1))
        connectionState = .connected
    }

    func disconnect() async {
        connectionState = .disconnected
    }
    #endif
}

#if os(macOS)
// MARK: - ICDeviceBrowserDelegate
extension ScannerManager: ICDeviceBrowserDelegate {
    nonisolated func deviceBrowser(_ browser: ICDeviceBrowser, didAdd device: ICDevice, moreComing: Bool) {
        // Log ALL devices found for debugging
        let deviceType = device is ICScannerDevice ? "SCANNER" : "OTHER"
        let locationDesc: String
        if device.usbLocationID != 0 {
            locationDesc = "USB"
        } else {
            locationDesc = "Network/Shared"
        }

        print("🔍 [ICDeviceBrowser] Device found: \(device.name ?? "Unknown") | Type: \(deviceType) | Location: \(locationDesc) | moreComing: \(moreComing)")

        if let scanner = device as? ICScannerDevice {
            Task { @MainActor in
                logger.info("✅ Scanner found: \(scanner.name ?? "Unknown"), location: \(locationDesc)")
                print("✅ Adding scanner to list: \(scanner.name ?? "Unknown")")
                if !self.availableScanners.contains(scanner) {
                    self.availableScanners.append(scanner)
                }
                if !moreComing {
                    logger.info("Scanner discovery batch complete, found \(self.availableScanners.count) scanner(s)")
                    self.connectionState = .disconnected
                }
            }
        } else {
            print("⚠️ Device is not a scanner: \(device.name ?? "Unknown")")
        }
    }

    nonisolated func deviceBrowser(_ browser: ICDeviceBrowser, didRemove device: ICDevice, moreGoing: Bool) {
        print("🗑️ [ICDeviceBrowser] Device removed: \(device.name ?? "Unknown")")
        if let scanner = device as? ICScannerDevice {
            Task { @MainActor in
                logger.info("Scanner removed: \(scanner.name ?? "Unknown")")
                self.availableScanners.removeAll { $0 == scanner }
            }
        }
    }

    nonisolated func deviceBrowser(_ browser: ICDeviceBrowser, didEncounterError error: Error) {
        print("❌ [ICDeviceBrowser] Error: \(error.localizedDescription)")
        Task { @MainActor in
            logger.error("Device browser error: \(error.localizedDescription)")
            self.connectionState = .error(error.localizedDescription)
            self.lastError = error.localizedDescription
        }
    }

    nonisolated func deviceBrowserDidEnumerateLocalDevices(_ browser: ICDeviceBrowser) {
        print("📋 [ICDeviceBrowser] Finished enumerating LOCAL devices")
    }
}

// MARK: - ICScannerDeviceDelegate
extension ScannerManager: ICScannerDeviceDelegate {
    nonisolated func didRemove(_ device: ICDevice) {
        if let scanner = device as? ICScannerDevice {
            Task { @MainActor in
                if scanner == selectedScanner {
                    selectedScanner = nil
                    connectionState = .disconnected
                }
            }
        }
    }

    nonisolated func device(_ device: ICDevice, didOpenSessionWithError error: Error?) {
        Task { @MainActor in
            if let error = error {
                connectionState = .error(error.localizedDescription)
                lastError = error.localizedDescription
            } else {
                connectionState = .connected
            }
        }
    }

    nonisolated func device(_ device: ICDevice, didCloseSessionWithError error: Error?) {
        Task { @MainActor in
            connectionState = .disconnected
            selectedScanner = nil
        }
    }

    nonisolated func scannerDevice(_ scanner: ICScannerDevice, didSelect functionalUnit: ICScannerFunctionalUnit, error: Error?) {
        if let error = error {
            Task { @MainActor in
                lastError = error.localizedDescription
            }
        }
    }

    nonisolated func scannerDevice(_ scanner: ICScannerDevice, didScanTo url: URL) {
        // Image was scanned successfully
        Task { @MainActor in
            guard let continuation = currentScanContinuation else { return }
            currentScanContinuation = nil

            do {
                guard let image = NSImage(contentsOf: url) else {
                    continuation.resume(throwing: ScannerError.scanFailed)
                    return
                }

                let metadata = ScanMetadata(
                    resolution: scanner.selectedFunctionalUnit.resolution,
                    colorSpace: "sRGB",
                    timestamp: Date(),
                    scannerModel: scanner.name ?? "Unknown Scanner",
                    width: Int(image.size.width),
                    height: Int(image.size.height),
                    bitDepth: scanner.selectedFunctionalUnit.pixelDataType == .BW ? 1 : 8
                )

                let result = ScanResult(image: image, metadata: metadata)
                continuation.resume(returning: result)

                // Clean up temporary file
                try? FileManager.default.removeItem(at: url)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    nonisolated func scannerDevice(_ scanner: ICScannerDevice, didCompleteOverviewScanWithError error: Error?) {
        if let error = error {
            Task { @MainActor in
                lastError = error.localizedDescription
            }
        }
    }

    nonisolated func scannerDevice(_ scanner: ICScannerDevice, didCompleteScanWithError error: Error?) {
        Task { @MainActor in
            guard let continuation = currentScanContinuation else { return }
            currentScanContinuation = nil

            if let error = error {
                continuation.resume(throwing: error)
            }
        }
    }
}
#endif

enum ScannerError: LocalizedError {
    case notConnected
    case connectionFailed
    case scanFailed
    case noScannersFound

    var errorDescription: String? {
        switch self {
        case .notConnected: return "Scanner is not connected"
        case .connectionFailed: return "Failed to connect to scanner"
        case .scanFailed: return "Scan operation failed"
        case .noScannersFound: return "No scanners found on network"
        }
    }
}
