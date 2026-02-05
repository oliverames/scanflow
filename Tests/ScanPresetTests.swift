//
//  ScanPresetTests.swift
//  ScanFlowTests
//
//  Tests for ScanPreset defaults.
//

import Testing
@testable import ScanFlow

@Suite("ScanPreset Tests")
struct ScanPresetTests {
    @Test("Defaults include searchable PDF preset")
    func defaultsIncludeSearchablePDF() {
        let preset = ScanPreset.searchablePDF
        #expect(preset.searchablePDF == true)
    }

    @Test("Default presets are not empty")
    func defaultPresetsNotEmpty() {
        #expect(!ScanPreset.defaults.isEmpty)
    }
}
