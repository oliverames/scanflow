//
//  ScannerManager.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

import Foundation
#if os(macOS)
import ImageCaptureCore
import AppKit
#endif

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
        deviceBrowser = ICDeviceBrowser()
        deviceBrowser?.delegate = self
        deviceBrowser?.browsedDeviceTypeMask = ICDeviceTypeMask.scanner
    }

    func discoverScanners() async {
        connectionState = .discovering

        // Clear previous scanners
        availableScanners.removeAll()

        deviceBrowser?.start()

        // Wait for discovery to complete (give it 5 seconds)
        try? await Task.sleep(for: .seconds(5))

        // Update state based on results
        if availableScanners.isEmpty {
            connectionState = .disconnected
        } else {
            connectionState = .disconnected
        }
    }

    func connect(to scanner: ICScannerDevice) async throws {
        connectionState = .connecting
        selectedScanner = scanner

        scanner.delegate = self
        try await scanner.requestOpenSession()

        // Wait for connection
        try await Task.sleep(for: .seconds(1))

        if scanner.hasOpenSession {
            connectionState = .connected
        } else {
            throw ScannerError.connectionFailed
        }
    }

    func connectMockScanner() async {
        connectionState = .connecting
        try? await Task.sleep(for: .seconds(1))
        connectionState = .connected
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
        if let scanner = device as? ICScannerDevice {
            Task { @MainActor in
                availableScanners.append(scanner)
                if !moreComing {
                    connectionState = .disconnected
                }
            }
        }
    }

    nonisolated func deviceBrowser(_ browser: ICDeviceBrowser, didRemove device: ICDevice, moreGoing: Bool) {
        if let scanner = device as? ICScannerDevice {
            Task { @MainActor in
                availableScanners.removeAll { $0 == scanner }
            }
        }
    }

    nonisolated func deviceBrowser(_ browser: ICDeviceBrowser, didEncounterError error: Error) {
        Task { @MainActor in
            connectionState = .error(error.localizedDescription)
            lastError = error.localizedDescription
        }
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
