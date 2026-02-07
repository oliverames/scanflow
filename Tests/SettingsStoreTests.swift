//
//  SettingsStoreTests.swift
//  ScanFlowTests
//
//  Tests for SettingsStore persistence behavior.
//

import Testing
import Foundation
@testable import ScanFlow

@Suite("SettingsStore Tests")
struct SettingsStoreTests {
    @Test("Naming settings persist via UserDefaults")
    func namingSettingsPersist() {
        let defaults = UserDefaults.standard
        let key = "defaultNamingSettings"
        let previous = defaults.data(forKey: key)
        defer {
            if let previous {
                defaults.set(previous, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        let store = SettingsStore()
        var settings = NamingSettings.default
        settings.enabled = true
        settings.includeDocumentType = false
        store.defaultNamingSettings = settings

        let reloaded = SettingsStore()
        #expect(reloaded.defaultNamingSettings == settings)
    }

    @Test("Separation settings persist via UserDefaults")
    func separationSettingsPersist() {
        let defaults = UserDefaults.standard
        let key = "defaultSeparationSettings"
        let previous = defaults.data(forKey: key)
        defer {
            if let previous {
                defaults.set(previous, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        let store = SettingsStore()
        var settings = SeparationSettings.default
        settings.enabled = true
        settings.useBarcodes = true
        settings.barcodePattern = "^SPLIT$"
        store.defaultSeparationSettings = settings

        let reloaded = SettingsStore()
        #expect(reloaded.defaultSeparationSettings == settings)
    }

    @Test("Remote scan server enabled flag persists")
    func remoteScanServerEnabledPersists() {
        let defaults = UserDefaults.standard
        let key = "remoteScanServerEnabled"
        let previous = defaults.object(forKey: key)
        defer {
            if let previous {
                defaults.set(previous, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        let store = SettingsStore()
        store.remoteScanServerEnabled = false

        let reloaded = SettingsStore()
        #expect(reloaded.remoteScanServerEnabled == false)
    }

    @Test("Advanced runtime settings persist")
    func advancedRuntimeSettingsPersist() {
        let defaults = UserDefaults.standard
        let discoveryKey = "scannerDiscoveryTimeoutSeconds"
        let timeoutKey = "scanTimeoutSeconds"
        let preserveKey = "preserveTemporaryScanFiles"
        let maxBufferedPagesKey = "maxBufferedPages"
        let requirePairingKey = "remoteScanRequirePairingToken"
        let pairingTokenKey = "remoteScanPairingToken"

        let previousDiscovery = defaults.object(forKey: discoveryKey)
        let previousTimeout = defaults.object(forKey: timeoutKey)
        let previousPreserve = defaults.object(forKey: preserveKey)
        let previousMaxBufferedPages = defaults.object(forKey: maxBufferedPagesKey)
        let previousRequirePairing = defaults.object(forKey: requirePairingKey)
        let previousPairingToken = defaults.object(forKey: pairingTokenKey)
        defer {
            if let previousDiscovery {
                defaults.set(previousDiscovery, forKey: discoveryKey)
            } else {
                defaults.removeObject(forKey: discoveryKey)
            }
            if let previousTimeout {
                defaults.set(previousTimeout, forKey: timeoutKey)
            } else {
                defaults.removeObject(forKey: timeoutKey)
            }
            if let previousPreserve {
                defaults.set(previousPreserve, forKey: preserveKey)
            } else {
                defaults.removeObject(forKey: preserveKey)
            }
            if let previousMaxBufferedPages {
                defaults.set(previousMaxBufferedPages, forKey: maxBufferedPagesKey)
            } else {
                defaults.removeObject(forKey: maxBufferedPagesKey)
            }
            if let previousRequirePairing {
                defaults.set(previousRequirePairing, forKey: requirePairingKey)
            } else {
                defaults.removeObject(forKey: requirePairingKey)
            }
            if let previousPairingToken {
                defaults.set(previousPairingToken, forKey: pairingTokenKey)
            } else {
                defaults.removeObject(forKey: pairingTokenKey)
            }
        }

        let store = SettingsStore()
        store.scannerDiscoveryTimeoutSeconds = 9
        store.scanTimeoutSeconds = 420
        store.preserveTemporaryScanFiles = true
        store.maxBufferedPages = 225
        store.remoteScanRequirePairingToken = true
        store.remoteScanPairingToken = "PAIR-TEST-0001"

        let reloaded = SettingsStore()
        #expect(reloaded.scannerDiscoveryTimeoutSeconds == 9)
        #expect(reloaded.scanTimeoutSeconds == 420)
        #expect(reloaded.preserveTemporaryScanFiles)
        #expect(reloaded.maxBufferedPages == 225)
        #expect(reloaded.remoteScanRequirePairingToken)
        #expect(reloaded.remoteScanPairingToken == "PAIR-TEST-0001")
    }
}
