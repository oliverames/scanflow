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
}
