//
//  DocumentActionAnalyzer.swift
//  ScanFlow
//
//  Parses document text for actionable items like events and contacts.
//

import Foundation

struct DocumentActionAnalyzer {
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    private let extractor = StructuredDataExtractor()

    func suggestions(from text: String, filename: String? = nil) -> [DocumentActionSuggestion] {
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedText.isEmpty else { return [] }

        let detections = extractor.extract(from: cleanedText)

        var suggestions: [DocumentActionSuggestion] = []

        if let eventDate = detections.dates.first {
            let title = inferredTitle(from: cleanedText, fallback: filename, defaultValue: "Scanned Event")
            let subtitle = "Date: \(dateFormatter.string(from: eventDate))"
            suggestions.append(
                DocumentActionSuggestion(
                    kind: .event,
                    title: title,
                    subtitle: subtitle,
                    date: eventDate,
                    duration: 3600
                )
            )
        }

        if let contactInfo = inferredContact(from: cleanedText, detections: detections) {
            var subtitleParts: [String] = []
            if let email = contactInfo.email { subtitleParts.append(email) }
            if let phone = contactInfo.phone { subtitleParts.append(phone) }
            let subtitle = subtitleParts.isEmpty ? "Contact details detected" : subtitleParts.joined(separator: " - ")

            suggestions.append(
                DocumentActionSuggestion(
                    kind: .contact,
                    title: contactInfo.displayName,
                    subtitle: subtitle,
                    contactName: contactInfo.displayName,
                    email: contactInfo.email,
                    phone: contactInfo.phone,
                    address: contactInfo.address
                )
            )
        }

        return suggestions
    }

    private func inferredTitle(from text: String, fallback: String?, defaultValue: String) -> String {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let firstLine = lines.first, firstLine.count <= 80 {
            return firstLine
        }

        if let fallback, !fallback.isEmpty {
            return fallback
        }

        return defaultValue
    }

    private func inferredContact(from text: String, detections: StructuredData) -> ContactInfo? {
        guard detections.emails.first != nil || detections.phones.first != nil || detections.addresses.first != nil else {
            return nil
        }

        let name = inferredName(from: text, email: detections.emails.first)
        let displayName = name ?? "New Contact"

        return ContactInfo(
            displayName: displayName,
            email: detections.emails.first,
            phone: detections.phones.first,
            address: detections.addresses.first
        )
    }

    private func inferredName(from text: String, email: String?) -> String? {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for line in lines.prefix(6) {
            if line.lowercased().hasPrefix("name:") {
                let value = line.replacingOccurrences(of: "name:", with: "", options: .caseInsensitive)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { return value }
            }
        }

        if let email {
            let handle = email.split(separator: "@").first.map(String.init)
            if let handle, !handle.isEmpty {
                let cleaned = handle
                    .replacingOccurrences(of: "_", with: " ")
                    .replacingOccurrences(of: ".", with: " ")
                let parts = cleaned.split(separator: " ").map { String($0).capitalized }
                if !parts.isEmpty {
                    return parts.joined(separator: " ")
                }
            }
        }

        for line in lines.prefix(4) {
            let words = line.split(separator: " ")
            if words.count >= 2 && words.count <= 4 {
                return line
            }
        }

        return nil
    }
}

private struct ContactInfo {
    let displayName: String
    let email: String?
    let phone: String?
    let address: String?
}
