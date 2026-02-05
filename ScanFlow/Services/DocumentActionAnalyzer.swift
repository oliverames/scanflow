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

    func suggestions(from text: String, filename: String? = nil) -> [DocumentActionSuggestion] {
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedText.isEmpty else { return [] }

        let detections = detectItems(in: cleanedText)

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

    private func detectItems(in text: String) -> DetectedItems {
        var dates: [Date] = []
        var emails: [String] = []
        var phones: [String] = []
        var addresses: [String] = []

        let types: NSTextCheckingResult.CheckingType = [.date, .phoneNumber, .link, .address]
        if let detector = try? NSDataDetector(types: types.rawValue) {
            let range = NSRange(text.startIndex..., in: text)
            detector.enumerateMatches(in: text, options: [], range: range) { result, _, _ in
                guard let result else { return }
                switch result.resultType {
                case .date:
                    if let date = result.date {
                        dates.append(date)
                    }
                case .phoneNumber:
                    if let phone = result.phoneNumber {
                        phones.append(phone)
                    }
                case .link:
                    if let url = result.url {
                        let value = url.absoluteString
                        if value.lowercased().hasPrefix("mailto:") {
                            emails.append(String(value.dropFirst("mailto:".count)))
                        } else if value.contains("@") {
                            emails.append(value)
                        }
                    }
                case .address:
                    if let addressComponents = result.addressComponents {
                        let formatted = addressComponents.values.joined(separator: ", ")
                        if !formatted.isEmpty {
                            addresses.append(formatted)
                        }
                    }
                default:
                    break
                }
            }
        }

        if emails.isEmpty {
            emails.append(contentsOf: regexEmails(in: text))
        }

        return DetectedItems(
            dates: unique(dates),
            emails: unique(emails),
            phones: unique(phones),
            addresses: unique(addresses)
        )
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

    private func inferredContact(from text: String, detections: DetectedItems) -> ContactInfo? {
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

    private func regexEmails(in text: String) -> [String] {
        let pattern = #"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }

    private func unique<T: Hashable>(_ values: [T]) -> [T] {
        var seen: Set<T> = []
        var result: [T] = []
        for value in values where !seen.contains(value) {
            seen.insert(value)
            result.append(value)
        }
        return result
    }
}

private struct DetectedItems {
    let dates: [Date]
    let emails: [String]
    let phones: [String]
    let addresses: [String]
}

private struct ContactInfo {
    let displayName: String
    let email: String?
    let phone: String?
    let address: String?
}
