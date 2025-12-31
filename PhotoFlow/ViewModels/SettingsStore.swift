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
    @AppStorage("useMockScanner") var useMockScanner: Bool = false

    // Barcode Settings
    @AppStorage("barcodeEnabled") var barcodeEnabled: Bool = false
    @AppStorage("barcodeUseForNaming") var barcodeUseForNaming: Bool = false
    @AppStorage("barcodeUseForSplitting") var barcodeUseForSplitting: Bool = false
    @AppStorage("barcodeSplitPattern") var barcodeSplitPattern: String = ""
    @AppStorage("barcodeUseForFolderRouting") var barcodeUseForFolderRouting: Bool = false
    @AppStorage("barcodeAddToMetadata") var barcodeAddToMetadata: Bool = true
    @AppStorage("barcodeMinimumConfidence") var barcodeMinimumConfidence: Double = 0.5

    // Imprinter Settings
    @AppStorage("imprinterEnabled") var imprinterEnabled: Bool = false
    @AppStorage("imprinterText") var imprinterText: String = ""
    @AppStorage("imprinterPosition") var imprinterPosition: String = "bottomRight"
    @AppStorage("imprinterRotation") var imprinterRotation: Int = 0
    @AppStorage("imprinterOpacity") var imprinterOpacity: Double = 1.0
    @AppStorage("imprinterFontSize") var imprinterFontSize: Double = 24.0
    @AppStorage("imprinterFontName") var imprinterFontName: String = "Helvetica-Bold"
    @AppStorage("imprinterTextColor") var imprinterTextColor: String = "#000000"
    @AppStorage("imprinterIncludeDate") var imprinterIncludeDate: Bool = false
    @AppStorage("imprinterIncludeTime") var imprinterIncludeTime: Bool = false
    @AppStorage("imprinterIncludePageNumbers") var imprinterIncludePageNumbers: Bool = false
}
