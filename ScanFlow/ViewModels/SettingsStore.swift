//
//  SettingsStore.swift
//  ScanFlow
//
//  Centralized settings management with UserDefaults persistence
//

import Foundation
import SwiftUI
import os.log

private let logger = Logger(subsystem: "com.scanflow.app", category: "SettingsStore")

/// Centralized settings store using @AppStorage for simple values
/// and explicit UserDefaults encoding for complex types.
final class SettingsStore: ObservableObject {
    
    // MARK: - Simple Settings (AppStorage)
    
    @AppStorage("defaultResolution") var defaultResolution: Int = 300
    @AppStorage("defaultFormat") var defaultFormat: String = "jpeg"
    @AppStorage("scanDestination") var scanDestination: String = "~/Pictures/Scans"
    @AppStorage("autoOpenDestination") var autoOpenDestination: Bool = true
    @AppStorage("organizationPattern") var organizationPattern: String = "date"
    @AppStorage("fileNamingTemplate") var fileNamingTemplate: String = "yyyy-MM-dd_###"
    @AppStorage("useMockScanner") var useMockScanner: Bool = false
    @AppStorage("keepConnectedInBackground") var keepConnectedInBackground: Bool = false
    @AppStorage("shouldPromptForBackgroundConnection") var shouldPromptForBackgroundConnection: Bool = true
    @AppStorage("hasConnectedScanner") var hasConnectedScanner: Bool = false
    @AppStorage("autoStartScanWhenReady") var autoStartScanWhenReady: Bool = false
    @AppStorage("startAtLogin") var startAtLogin: Bool = false
    
    // MARK: - Complex Settings (Codable)
    
    private static let namingSettingsKey = "defaultNamingSettings"
    private static let separationSettingsKey = "defaultSeparationSettings"
    private static let autoStartScannerIDsKey = "autoStartScannerIDs"
    
    /// AI-assisted file naming default settings
    var defaultNamingSettings: NamingSettings {
        get {
            loadCodable(forKey: Self.namingSettingsKey) ?? .default
        }
        set {
            saveCodable(newValue, forKey: Self.namingSettingsKey)
        }
    }
    
    /// Document separation default settings
    var defaultSeparationSettings: SeparationSettings {
        get {
            loadCodable(forKey: Self.separationSettingsKey) ?? .default
        }
        set {
            saveCodable(newValue, forKey: Self.separationSettingsKey)
        }
    }

    /// Scanners allowed to auto-start when detected
    var autoStartScannerIDs: Set<String> {
        get {
            let stored: [String] = loadCodable(forKey: Self.autoStartScannerIDsKey) ?? []
            return Set(stored)
        }
        set {
            let stored = Array(newValue).sorted()
            saveCodable(stored, forKey: Self.autoStartScannerIDsKey)
        }
    }
    
    // MARK: - Private Helpers
    
    /// Load a Codable value from UserDefaults with error handling
    private func loadCodable<T: Codable>(forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            logger.error("Failed to decode \(key): \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Save a Codable value to UserDefaults with error handling
    private func saveCodable<T: Codable>(_ value: T, forKey key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            UserDefaults.standard.set(data, forKey: key)
            logger.debug("Saved \(key) to UserDefaults")
        } catch {
            logger.error("Failed to encode \(key): \(error.localizedDescription)")
        }
    }
    
    // MARK: - Reset
    
    /// Reset all settings to defaults
    func resetToDefaults() {
        logger.info("Resetting all settings to defaults")
        
        defaultResolution = 300
        defaultFormat = "jpeg"
        scanDestination = "~/Pictures/Scans"
        autoOpenDestination = true
        organizationPattern = "date"
        fileNamingTemplate = "yyyy-MM-dd_###"
        useMockScanner = false
        keepConnectedInBackground = false
        shouldPromptForBackgroundConnection = true
        hasConnectedScanner = false
        autoStartScanWhenReady = false
        startAtLogin = false
        
        UserDefaults.standard.removeObject(forKey: Self.namingSettingsKey)
        UserDefaults.standard.removeObject(forKey: Self.separationSettingsKey)
        UserDefaults.standard.removeObject(forKey: Self.autoStartScannerIDsKey)
    }
}
