//
//  SettingsStore.swift
//  PhotoFlow
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
    @AppStorage("useMockScanner") var useMockScanner: Bool = true
}
