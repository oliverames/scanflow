//
//  TWAINBridgeTests.swift
//  ScanFlowTests
//
//  Tests for TWAIN bridge fallback behavior.
//

import Testing
#if os(macOS)
import AppKit
#endif
@testable import ScanFlow

#if os(macOS)
@Suite("TWAINBridge Tests")
struct TWAINBridgeTests {
    @Test("Scan requires connection")
    @MainActor
    func scanRequiresConnection() async {
        let manager = ScannerManager()
        let bridge = TWAINBridge(scannerManager: manager)

        do {
            _ = try await bridge.scan(with: .init())
            Issue.record("Expected notConnected error")
        } catch let error as TWAINError {
            switch error {
            case .notConnected:
                #expect(Bool(true))
            default:
                Issue.record("Expected notConnected, got \(error.localizedDescription)")
            }
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }

    @Test("Uses scanner manager fallback when connected mock scanner is enabled")
    @MainActor
    func scanUsesFallbackWithMockScanner() async throws {
        let manager = ScannerManager()
        manager.useMockScanner = true
        manager.connectionState = .connected
        let bridge = TWAINBridge(scannerManager: manager)

        try await bridge.setBrightness(20)
        try await bridge.setContrast(-15)
        try await bridge.setExposure(5)

        let images = try await bridge.scan(with: .init(
            resolution: 300,
            colorMode: .color,
            paperSize: .letter,
            source: .flatbed,
            duplex: false
        ))

        #expect(!images.isEmpty)
        #expect(images.first?.size.width ?? 0 > 0)
    }

    @Test("Runtime TWAIN settings are clamped to safe ranges")
    @MainActor
    func runtimeSettingsAreClamped() async throws {
        let manager = ScannerManager()
        let bridge = TWAINBridge(scannerManager: manager)

        try await bridge.setBrightness(240)
        try await bridge.setContrast(-220)
        try await bridge.setExposure(300)
        try await bridge.setThreshold(1000)

        let settings = bridge.currentSettings
        #expect(settings.brightness == 100)
        #expect(settings.contrast == -100)
        #expect(settings.exposure == 100)
        #expect(settings.threshold == 255)
    }

    @Test("Rejects unsupported TWAIN source capabilities")
    @MainActor
    func rejectsUnsupportedSourceCapabilities() async throws {
        let manager = ScannerManager()
        manager.useMockScanner = true
        manager.connectionState = .connected
        let bridge = TWAINBridge(scannerManager: manager)
        bridge.overrideCapabilitiesForTesting(.init(
            supportsDuplex: false,
            supportsADF: false,
            supportsFlatbed: true,
            maxResolution: 600,
            minResolution: 75,
            supportedColorModes: ["Color", "Grayscale", "BlackWhite"],
            supportedPaperSizes: ["Letter", "A4"],
            model: "Test",
            manufacturer: "Unit"
        ))

        do {
            _ = try await bridge.scan(with: .init(source: .adf, duplex: false))
            Issue.record("Expected unsupported ADF capability error")
        } catch let error as TWAINError {
            switch error {
            case .capabilityNotSupported(let capability):
                #expect(capability.contains("ADF"))
            default:
                Issue.record("Unexpected TWAINError: \(error.localizedDescription)")
            }
        }
    }

    @Test("Rejects unsupported color mode capability")
    @MainActor
    func rejectsUnsupportedColorModeCapability() async throws {
        let manager = ScannerManager()
        manager.useMockScanner = true
        manager.connectionState = .connected
        let bridge = TWAINBridge(scannerManager: manager)
        bridge.overrideCapabilitiesForTesting(.init(
            supportsDuplex: true,
            supportsADF: true,
            supportsFlatbed: true,
            maxResolution: 600,
            minResolution: 75,
            supportedColorModes: ["Color"],
            supportedPaperSizes: ["Letter", "A4"],
            model: "Test",
            manufacturer: "Unit"
        ))

        do {
            _ = try await bridge.scan(with: .init(colorMode: .blackWhite, source: .flatbed))
            Issue.record("Expected unsupported color mode capability error")
        } catch let error as TWAINError {
            switch error {
            case .capabilityNotSupported(let capability):
                #expect(capability.contains("Color mode"))
            default:
                Issue.record("Unexpected TWAINError: \(error.localizedDescription)")
            }
        }
    }

    @Test("Auto source falls back to flatbed when ADF is unavailable")
    @MainActor
    func autoSourceFallbacksToFlatbed() async throws {
        let manager = ScannerManager()
        manager.useMockScanner = true
        manager.connectionState = .connected
        let bridge = TWAINBridge(scannerManager: manager)
        bridge.overrideCapabilitiesForTesting(.init(
            supportsDuplex: false,
            supportsADF: false,
            supportsFlatbed: true,
            maxResolution: 600,
            minResolution: 75,
            supportedColorModes: ["Color", "Grayscale", "BlackWhite"],
            supportedPaperSizes: ["Letter", "A4"],
            model: "Test",
            manufacturer: "Unit"
        ))

        _ = try await bridge.scan(with: .init(source: .auto, autoFeed: true))
        #expect(bridge.currentSettings.source == .flatbed)
        #expect(bridge.currentSettings.autoFeed == false)
    }

    @Test("Scan without explicit settings uses active TWAIN settings")
    @MainActor
    func scanUsesActiveSettings() async throws {
        let manager = ScannerManager()
        manager.useMockScanner = true
        manager.connectionState = .connected
        let bridge = TWAINBridge(scannerManager: manager)

        try await bridge.setThreshold(32)
        let images = try await bridge.scan()

        #expect(!images.isEmpty)
        #expect(bridge.currentSettings.threshold == 32)
    }

    @Test("Disconnect clears TWAIN state")
    @MainActor
    func disconnectClearsState() async throws {
        let manager = ScannerManager()
        manager.connectionState = .connected
        manager.useMockScanner = true
        let bridge = TWAINBridge(scannerManager: manager)

        try await bridge.setThreshold(45)
        #expect(bridge.currentSettings.threshold == 45)

        await bridge.disconnect()

        #expect(bridge.currentSettings == TWAINBridge.TWAINSettings())
        #expect(manager.connectionState == .disconnected)
    }
}
#endif
