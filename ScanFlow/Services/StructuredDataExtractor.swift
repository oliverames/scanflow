//
//  StructuredDataExtractor.swift
//  ScanFlow
//
//  Extracts structured data (dates, contacts, emails, phones, addresses) from text.
//

import Foundation

struct StructuredData {
    let dates: [Date]
    let emails: [String]
    let phones: [String]
    let addresses: [String]
}

struct StructuredDataExtractor {
    func extract(from text: String) -> StructuredData {
        let cleanedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedText.isEmpty else {
            return StructuredData(dates: [], emails: [], phones: [], addresses: [])
        }

        var dates: [Date] = []
        var emails: [String] = []
        var phones: [String] = []
        var addresses: [String] = []

        let types: NSTextCheckingResult.CheckingType = [.date, .phoneNumber, .link, .address]
        if let detector = try? NSDataDetector(types: types.rawValue) {
            let range = NSRange(cleanedText.startIndex..., in: cleanedText)
            detector.enumerateMatches(in: cleanedText, options: [], range: range) { result, _, _ in
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
            emails.append(contentsOf: regexEmails(in: cleanedText))
        }

        return StructuredData(
            dates: unique(dates),
            emails: unique(emails),
            phones: unique(phones),
            addresses: unique(addresses)
        )
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
