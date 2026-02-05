//
//  StructuredDataExtractorTests.swift
//  ScanFlowTests
//
//  Tests for structured data extraction.
//

import Testing
import Foundation
@testable import ScanFlow

@Suite("StructuredDataExtractor Tests")
struct StructuredDataExtractorTests {
    @Test("Extracts dates, emails, and phone numbers")
    func extractsCoreFields() {
        let extractor = StructuredDataExtractor()
        let text = "Meeting on March 10, 2026 at 2:00 PM. Contact: jane.doe@example.com or (415) 555-0100."

        let result = extractor.extract(from: text)

        #expect(!result.dates.isEmpty)
        #expect(result.emails.contains("jane.doe@example.com"))
        #expect(result.phones.contains { $0.contains("555") })
    }

    @Test("Empty text returns empty result")
    func emptyTextReturnsEmpty() {
        let extractor = StructuredDataExtractor()
        let result = extractor.extract(from: "   ")

        #expect(result.dates.isEmpty)
        #expect(result.emails.isEmpty)
        #expect(result.phones.isEmpty)
        #expect(result.addresses.isEmpty)
    }
}
