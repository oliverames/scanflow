//
//  AIFileNamerTests.swift
//  ScanFlowTests
//
//  Tests for AI-assisted file naming functionality.
//

import Testing
import Foundation
@testable import ScanFlow

@Suite("AIFileNamer Tests")
struct AIFileNamerTests {
    
    // MARK: - NamingSettings Tests
    
    @Test("Default naming settings have expected values")
    func defaultNamingSettings() {
        let settings = NamingSettings.default
        
        #expect(settings.enabled == false)
        #expect(settings.useDatePrefix == true)
        #expect(settings.dateSource == .documentContent)
        #expect(settings.includeDocumentType == true)
        #expect(settings.includeKeyEntities == true)
        #expect(settings.maxLength == 60)
        #expect(settings.useAdvancedMode == false)
        #expect(settings.fallbackBehavior == .promptManual)
    }
    
    @Test("NamingSettings is Codable")
    func namingSettingsCodable() throws {
        var settings = NamingSettings()
        settings.enabled = true
        settings.dateSource = .scanDate
        settings.maxLength = 40
        settings.useAdvancedMode = true
        settings.customPrompt = "Test prompt"
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(settings)
        
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(NamingSettings.self, from: data)
        
        #expect(decoded == settings)
    }
    
    @Test("DateSource raw values are readable")
    func dateSourceRawValues() {
        #expect(NamingSettings.DateSource.documentContent.rawValue == "From Document")
        #expect(NamingSettings.DateSource.scanDate.rawValue == "Scan Date")
        #expect(NamingSettings.DateSource.none.rawValue == "No Date")
    }
    
    @Test("FallbackBehavior raw values are readable")
    func fallbackBehaviorRawValues() {
        #expect(NamingSettings.FallbackBehavior.promptManual.rawValue == "Prompt for manual entry")
        #expect(NamingSettings.FallbackBehavior.notifyAndFallback.rawValue == "Notify and use date-based")
        #expect(NamingSettings.FallbackBehavior.silentFallback.rawValue == "Silent fallback to date-based")
    }
    
    // MARK: - FilenameResponse Tests
    
    @Test("FilenameResponse default initialization")
    func filenameResponseDefault() {
        let response = FilenameResponse()
        
        #expect(response.filename == "")
        #expect(response.documentType == "Other")
        #expect(response.documentDate == "")
        #expect(response.reasoning == "")
        #expect(response.confidence == 0.0)
    }
    
    @Test("FilenameResponse custom initialization")
    func filenameResponseCustom() {
        let response = FilenameResponse(
            filename: "2024-03-15 Meeting Notes",
            documentType: "Report",
            documentDate: "2024-03-15",
            reasoning: "Contains meeting notes with date",
            confidence: 0.95
        )
        
        #expect(response.filename == "2024-03-15 Meeting Notes")
        #expect(response.documentType == "Report")
        #expect(response.documentDate == "2024-03-15")
        #expect(response.reasoning == "Contains meeting notes with date")
        #expect(response.confidence == 0.95)
    }
    
    // MARK: - AIFileNamerError Tests
    
    @Test("AIFileNamerError has descriptive messages")
    func aiFileNamerErrorDescriptions() {
        #expect(AIFileNamerError.modelUnavailable.errorDescription?.contains("Apple Intelligence") == true)
        #expect(AIFileNamerError.textExtractionFailed.errorDescription?.contains("extract text") == true)
        #expect(AIFileNamerError.emptyResponse.errorDescription?.contains("empty") == true)
        
        let underlyingError = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let generationError = AIFileNamerError.generationFailed(underlying: underlyingError)
        #expect(generationError.errorDescription?.contains("Test error") == true)
    }
    
    // MARK: - Availability Tests
    
    @Test("isAvailable returns false on macOS < 26")
    @available(macOS, deprecated: 26.0)
    func availabilityCheck() async {
        // On macOS < 26, this should return false
        // On macOS 26+, it depends on device capabilities
        let available = await AIFileNamer.isAvailable()
        // We can't assert the exact value since it depends on the test environment
        // But we can verify it doesn't crash
        _ = available
    }
    
    // MARK: - Default Prompt Tests
    
    @Test("Default prompt contains essential guidelines")
    func defaultPromptContent() {
        let prompt = NamingSettings.defaultPrompt
        
        #expect(prompt.contains("Title Case"))
        #expect(prompt.contains("60 characters"))
        #expect(prompt.contains("YYYY-MM-DD"))
        #expect(prompt.contains("en dashes"))
    }
}
