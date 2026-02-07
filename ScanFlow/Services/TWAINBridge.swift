//
//  TWAINBridge.swift
//  ScanFlow
//
//  TWAIN-oriented interface with ImageCaptureCore fallback.
//

import Foundation
#if os(macOS)
import AppKit
@preconcurrency import ImageCaptureCore
#endif

#if os(macOS)

@MainActor
final class TWAINBridge {

    struct TWAINCapabilities: Codable, Equatable {
        var supportsDuplex: Bool = false
        var supportsADF: Bool = false
        var supportsFlatbed: Bool = true
        var maxResolution: Int = 1200
        var minResolution: Int = 75
        var supportedColorModes: [String] = ["Color", "Grayscale", "BlackWhite"]
        var supportedPaperSizes: [String] = ["Letter", "Legal", "A4", "A5"]
        var model: String = "Unknown"
        var manufacturer: String = "Unknown"
    }

    struct TWAINSettings: Codable, Equatable {
        var resolution: Int = 300
        var colorMode: ColorMode = .color
        var paperSize: PaperSize = .letter
        var source: Source = .flatbed
        var duplex: Bool = false
        var autoFeed: Bool = false
        var brightness: Double = 0.0  // -100 to 100
        var contrast: Double = 0.0    // -100 to 100
        var threshold: Int = 128      // For B&W, 0-255
        var exposure: Double = 0.0    // -100 to 100

        enum ColorMode: String, Codable, CaseIterable {
            case color = "Color"
            case grayscale = "Grayscale"
            case blackWhite = "BlackWhite"
        }

        enum Source: String, Codable, CaseIterable {
            case flatbed = "Flatbed"
            case adf = "ADF"
            case auto = "Auto"
        }

        enum PaperSize: String, Codable, CaseIterable {
            case letter = "Letter"
            case legal = "Legal"
            case a4 = "A4"
            case a5 = "A5"
            case custom = "Custom"
        }
    }

    private let scannerManager: ScannerManager
    private(set) var isNativeTWAINAvailable: Bool = false
    private var currentCapabilities: TWAINCapabilities?
    private var connectedScannerName: String?
    private var activeSettings = TWAINSettings()
    private var capabilityOverride: TWAINCapabilities?

    init(scannerManager: ScannerManager) {
        self.scannerManager = scannerManager
        checkTWAINAvailability()
    }

    convenience init() {
        self.init(scannerManager: ScannerManager())
    }

    var isTWAINAvailable: Bool {
        isNativeTWAINAvailable || !scannerManager.availableScanners.isEmpty
    }

    var currentSettings: TWAINSettings {
        activeSettings
    }

    var isConnected: Bool {
        scannerManager.connectionState.isConnected && connectedScannerName != nil
    }

    func discoverTWAINScanners() async throws -> [String] {
        checkTWAINAvailability()
        await scannerManager.discoverScanners()
        return scannerManager.availableScanners.compactMap(\.name).sorted()
    }

    func connect(to scannerName: String) async throws -> TWAINCapabilities {
        if scannerManager.availableScanners.isEmpty {
            _ = try await discoverTWAINScanners()
        }

        guard let scanner = locateScanner(named: scannerName) else {
            throw TWAINError.scannerNotFound
        }

        try await scannerManager.connect(to: scanner)
        connectedScannerName = scanner.name
        let caps = capabilities(for: scanner)
        currentCapabilities = caps
        activeSettings = normalizedDefaultSettings(for: caps)
        return caps
    }

    func disconnect() async {
        await scannerManager.disconnect()
        connectedScannerName = nil
        currentCapabilities = nil
        activeSettings = TWAINSettings()
    }

    func scan() async throws -> [NSImage] {
        try await scan(with: activeSettings)
    }

    func scan(with settings: TWAINSettings) async throws -> [NSImage] {
        guard scannerManager.connectionState.isConnected else {
            throw TWAINError.notConnected
        }

        let normalized = try normalizedSettings(for: settings, allowDisconnectedFallback: false)
        activeSettings = normalized
        let preset = twainPreset(for: normalized)
        let result = try await scannerManager.scan(with: preset)
        return result.images
    }

    func getCapabilities() async throws -> TWAINCapabilities {
        guard scannerManager.connectionState.isConnected else {
            throw TWAINError.notConnected
        }

        if let scanner = scannerManager.selectedScanner {
            currentCapabilities = capabilities(for: scanner)
        }
        guard let currentCapabilities else {
            throw TWAINError.notConnected
        }
        return currentCapabilities
    }

    func setBrightness(_ value: Double) async throws {
        activeSettings.brightness = clampSignedPercentage(value)
    }

    func setContrast(_ value: Double) async throws {
        activeSettings.contrast = clampSignedPercentage(value)
    }

    func setExposure(_ value: Double) async throws {
        activeSettings.exposure = clampSignedPercentage(value)
    }

    func setThreshold(_ value: Int) async throws {
        activeSettings.threshold = min(max(value, 0), 255)
    }

    func setResolution(_ value: Int) async throws {
        try applySettingMutation { settings in
            settings.resolution = value
        }
    }

    func setColorMode(_ value: TWAINSettings.ColorMode) async throws {
        try applySettingMutation { settings in
            settings.colorMode = value
        }
    }

    func setPaperSize(_ value: TWAINSettings.PaperSize) async throws {
        try applySettingMutation { settings in
            settings.paperSize = value
        }
    }

    func setSource(_ value: TWAINSettings.Source) async throws {
        try applySettingMutation { settings in
            settings.source = value
        }
    }

    func setDuplexEnabled(_ enabled: Bool) async throws {
        try applySettingMutation { settings in
            settings.duplex = enabled
        }
    }

    func setAutoFeedEnabled(_ enabled: Bool) async throws {
        try applySettingMutation { settings in
            settings.autoFeed = enabled
        }
    }

    func updateSettings(_ settings: TWAINSettings) async throws {
        activeSettings = try normalizedSettings(for: settings, allowDisconnectedFallback: true)
    }

    // Test-only capability override used to validate normalization paths deterministically.
    func overrideCapabilitiesForTesting(_ capabilities: TWAINCapabilities?) {
        capabilityOverride = capabilities
    }

    private func checkTWAINAvailability() {
        let fm = FileManager.default
        let candidatePaths = [
            "/Library/Image Capture/TWAIN Data Sources",
            "/System/Library/Image Capture/TWAIN Data Sources",
            "/Library/Frameworks/TWAINDSM.framework",
            "/System/Library/Frameworks/TWAIN.framework"
        ]
        isNativeTWAINAvailable = candidatePaths.contains { fm.fileExists(atPath: $0) }
    }

    private func locateScanner(named scannerName: String) -> ICScannerDevice? {
        scannerManager.availableScanners.first { scanner in
            (scanner.name ?? "").localizedCaseInsensitiveCompare(scannerName) == .orderedSame
        }
    }

    private func capabilities(for scanner: ICScannerDevice) -> TWAINCapabilities {
        var capabilities = TWAINCapabilities()
        let units = scanner.availableFunctionalUnitTypes
        capabilities.supportsFlatbed = units.contains(NSNumber(value: ICScannerFunctionalUnitType.flatbed.rawValue))
        capabilities.supportsADF = units.contains(NSNumber(value: ICScannerFunctionalUnitType.documentFeeder.rawValue))

        if let feeder = scanner.selectedFunctionalUnit as? ICScannerFunctionalUnitDocumentFeeder {
            capabilities.supportsDuplex = feeder.supportsDuplexScanning
        } else {
            capabilities.supportsDuplex = false
        }

        let resolutions = Array(scanner.selectedFunctionalUnit.supportedResolutions)
        if let minResolution = resolutions.min() {
            capabilities.minResolution = minResolution
        }
        if let maxResolution = resolutions.max() {
            capabilities.maxResolution = maxResolution
        }

        capabilities.model = scanner.name ?? "Unknown"
        capabilities.manufacturer = scanner.productKind ?? "Unknown"
        return capabilities
    }

    private func twainPreset(for settings: TWAINSettings) -> ScanPreset {
        var preset = ScanPreset.quickScan
        preset.name = connectedScannerName ?? "TWAIN Scan"
        preset.resolution = settings.resolution
        preset.colorMode = scanColorMode(from: settings.colorMode)
        preset.paperSize = scanPaperSize(from: settings.paperSize)
        preset.source = scanSource(from: settings.source, duplex: settings.duplex, autoFeed: settings.autoFeed)
        preset.useDuplex = settings.duplex
        preset.brightness = clampNormalized(settings.brightness)
        preset.contrast = clampNormalized(settings.contrast)
        preset.bwThreshold = min(max(settings.threshold, 0), 255)
        return preset
    }

    private func normalizedDefaultSettings(for capabilities: TWAINCapabilities) -> TWAINSettings {
        var settings = TWAINSettings()
        settings.resolution = min(max(settings.resolution, capabilities.minResolution), capabilities.maxResolution)
        if !capabilities.supportsFlatbed, capabilities.supportsADF {
            settings.source = .adf
            settings.autoFeed = true
        }
        if !capabilities.supportsDuplex {
            settings.duplex = false
        }
        return settings
    }

    private func normalizedSettings(for settings: TWAINSettings, allowDisconnectedFallback: Bool) throws -> TWAINSettings {
        let capabilities: TWAINCapabilities
        if let resolved = try? resolvedCapabilities() {
            capabilities = resolved
        } else if allowDisconnectedFallback {
            capabilities = TWAINCapabilities()
        } else {
            throw TWAINError.notConnected
        }
        var normalized = settings
        normalized.resolution = min(max(settings.resolution, capabilities.minResolution), capabilities.maxResolution)
        normalized.brightness = clampSignedPercentage(settings.brightness)
        normalized.contrast = clampSignedPercentage(settings.contrast)
        normalized.exposure = clampSignedPercentage(settings.exposure)
        normalized.threshold = min(max(settings.threshold, 0), 255)

        if !capabilities.supportedColorModes.contains(normalized.colorMode.rawValue) {
            throw TWAINError.capabilityNotSupported("Color mode \(normalized.colorMode.rawValue)")
        }

        if normalized.paperSize != .custom && !capabilities.supportedPaperSizes.contains(normalized.paperSize.rawValue) {
            throw TWAINError.capabilityNotSupported("Paper size \(normalized.paperSize.rawValue)")
        }

        if normalized.source == .auto {
            if normalized.autoFeed && capabilities.supportsADF {
                normalized.source = .adf
            } else if capabilities.supportsFlatbed {
                normalized.source = .flatbed
            } else if capabilities.supportsADF {
                normalized.source = .adf
            } else {
                throw TWAINError.capabilityNotSupported("Any scan source")
            }
        }

        if normalized.source == .flatbed {
            if !capabilities.supportsFlatbed {
                throw TWAINError.capabilityNotSupported("Flatbed source")
            }
            normalized.autoFeed = false
            normalized.duplex = false
        } else if normalized.source == .adf {
            if !capabilities.supportsADF {
                throw TWAINError.capabilityNotSupported("ADF source")
            }
            normalized.autoFeed = true
        }

        if normalized.duplex && !capabilities.supportsDuplex {
            throw TWAINError.capabilityNotSupported("Duplex scanning")
        }
        return normalized
    }

    private func applySettingMutation(_ mutation: (inout TWAINSettings) -> Void) throws {
        var settings = activeSettings
        mutation(&settings)
        activeSettings = try normalizedSettings(for: settings, allowDisconnectedFallback: true)
    }

    private func resolvedCapabilities() throws -> TWAINCapabilities {
        if let capabilityOverride {
            return capabilityOverride
        }
        if let caps = currentCapabilities {
            return caps
        }
        if let scanner = scannerManager.selectedScanner {
            let caps = capabilities(for: scanner)
            currentCapabilities = caps
            return caps
        }
        if scannerManager.useMockScanner {
            return TWAINCapabilities(
                supportsDuplex: true,
                supportsADF: true,
                supportsFlatbed: true,
                maxResolution: 1200,
                minResolution: 75,
                supportedColorModes: ["Color", "Grayscale", "BlackWhite"],
                supportedPaperSizes: ["Letter", "Legal", "A4", "A5"],
                model: scannerManager.mockScannerName,
                manufacturer: "Mock"
            )
        }
        throw TWAINError.notConnected
    }

    private func scanColorMode(from colorMode: TWAINSettings.ColorMode) -> ColorMode {
        switch colorMode {
        case .color: return .color
        case .grayscale: return .grayscale
        case .blackWhite: return .blackWhite
        }
    }

    private func scanPaperSize(from paperSize: TWAINSettings.PaperSize) -> ScanPaperSize {
        switch paperSize {
        case .letter: return .letter
        case .legal: return .legal
        case .a4: return .a4
        case .a5: return .a5
        case .custom: return .custom
        }
    }

    private func scanSource(from source: TWAINSettings.Source, duplex: Bool, autoFeed: Bool) -> ScanSource {
        switch source {
        case .flatbed:
            return .flatbed
        case .adf:
            return duplex ? .adfDuplex : .adfFront
        case .auto:
            if autoFeed, let caps = currentCapabilities, caps.supportsADF {
                return duplex ? .adfDuplex : .adfFront
            }
            return .flatbed
        }
    }

    private func clampSignedPercentage(_ value: Double) -> Double {
        min(max(value, -100), 100)
    }

    private func clampNormalized(_ value: Double) -> Double {
        let normalized = value / 100.0
        return min(max(normalized, -1.0), 1.0)
    }
}

enum TWAINError: LocalizedError {
    case nativeBridgeNotAvailable
    case notConnected
    case scannerNotFound
    case scanFailed
    case capabilityNotSupported(String)

    var errorDescription: String? {
        switch self {
        case .nativeBridgeNotAvailable:
            return "TWAIN native bridge not available. Falling back to ImageCaptureCore."
        case .notConnected:
            return "Not connected to a scanner"
        case .scannerNotFound:
            return "Scanner not found"
        case .scanFailed:
            return "Scan operation failed"
        case .capabilityNotSupported(let capability):
            return "Scanner does not support this capability: \(capability)"
        }
    }
}

#endif
