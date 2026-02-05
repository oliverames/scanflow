//
//  SettingsStore.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-31.
//

import Foundation
import SwiftUI

/// Separate settings store using traditional ObservableObject to avoid
/// conflict between @Observable macro and @AppStorage property wrapper.
final class SettingsStore: ObservableObject {
    @AppStorage("defaultResolution") var defaultResolution: Int = 300
    @AppStorage("defaultFormat") var defaultFormat: String = "jpeg"
    @AppStorage("scanDestination") var scanDestination: String = "~/Pictures/Scans"
    @AppStorage("autoOpenDestination") var autoOpenDestination: Bool = true
    @AppStorage("organizationPattern") var organizationPattern: String = "date"
    @AppStorage("fileNamingTemplate") var fileNamingTemplate: String = "yyyy-MM-dd_###"
    @AppStorage("useMockScanner") var useMockScanner: Bool = false

    // AI-assisted file naming default settings
    var defaultNamingSettings: NamingSettings {
        get {
            guard let data = UserDefaults.standard.data(forKey: "defaultNamingSettings"),
                  let settings = try? JSONDecoder().decode(NamingSettings.self, from: data) else {
                return .default
            }
            return settings
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "defaultNamingSettings")
            }
        }
    }

    // Document separation default settings
    var defaultSeparationSettings: SeparationSettings {
        get {
            guard let data = UserDefaults.standard.data(forKey: "defaultSeparationSettings"),
                  let settings = try? JSONDecoder().decode(SeparationSettings.self, from: data) else {
                return .default
            }
            return settings
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "defaultSeparationSettings")
            }
        }
    }
}
