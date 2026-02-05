//
//  DocumentActionAnalyzerTests.swift
//  ScanFlowTests
//
//  Tests for document action detection.
//

import Testing
import Foundation
@testable import ScanFlow

@Suite("DocumentActionAnalyzer Tests")
struct DocumentActionAnalyzerTests {
    @Test("Detects event suggestion from date")
    func detectsEventSuggestion() {
        let analyzer = DocumentActionAnalyzer()
        let text = "Team review meeting on March 10, 2026 at 2:00 PM in Conference Room A."

        let suggestions = analyzer.suggestions(from: text, filename: "Review Notes")
        let event = suggestions.first { $0.kind == .event }

        #expect(event != nil)
        #expect(event?.date != nil)
        #expect(event?.title == "Team review meeting on March 10, 2026 at 2:00 PM in Conference Room A." || event?.title == "Review Notes")
    }

    @Test("Detects contact suggestion from email and phone")
    func detectsContactSuggestion() {
        let analyzer = DocumentActionAnalyzer()
        let text = "Name: Jane Doe\nEmail: jane.doe@example.com\nPhone: (415) 555-0100"

        let suggestions = analyzer.suggestions(from: text, filename: nil)
        let contact = suggestions.first { $0.kind == .contact }

        #expect(contact != nil)
        #expect(contact?.contactName == "Jane Doe")
        #expect(contact?.email == "jane.doe@example.com")
        #expect(contact?.phone?.contains("555") == true)
    }

    @Test("Empty text returns no suggestions")
    func emptyTextReturnsNoSuggestions() {
        let analyzer = DocumentActionAnalyzer()
        let suggestions = analyzer.suggestions(from: "  ", filename: nil)
        #expect(suggestions.isEmpty)
    }
}
