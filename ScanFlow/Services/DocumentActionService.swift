//
//  DocumentActionService.swift
//  ScanFlow
//
//  Bridges detected document actions to Calendar and Contacts.
//

import Foundation
#if os(macOS)
import AppKit
import PDFKit
import EventKit
import Contacts
#endif

@MainActor
public final class DocumentActionService {
    #if os(macOS)
    private let imageProcessor: ImageProcessor
    private let analyzer = DocumentActionAnalyzer()
    private let eventStore = EKEventStore()
    private let contactStore = CNContactStore()

    public init(imageProcessor: ImageProcessor) {
        self.imageProcessor = imageProcessor
    }

    func suggestions(for file: ScannedFile) async throws -> [DocumentActionSuggestion] {
        let text = try await extractText(from: file)
        return analyzer.suggestions(from: text, filename: file.filename)
    }

    func createAction(from suggestion: DocumentActionSuggestion) async throws {
        switch suggestion.kind {
        case .event:
            try await createEvent(from: suggestion)
        case .contact:
            try await createContact(from: suggestion)
        }
    }

    private func extractText(from file: ScannedFile) async throws -> String {
        let url = file.fileURL
        let ext = url.pathExtension.lowercased()

        if ext == "pdf", let document = PDFDocument(url: url) {
            if let string = document.string?.trimmingCharacters(in: .whitespacesAndNewlines), !string.isEmpty {
                return string
            }

            let pageCount = document.pageCount
            if pageCount > 0 {
                let maxPages = min(5, pageCount)
                var combinedText: [String] = []
                for index in 0..<maxPages {
                    if let page = document.page(at: index) {
                        let image = page.thumbnail(of: NSSize(width: 1600, height: 2000), for: .mediaBox)
                        let pageText = try await imageProcessor.recognizeText(image)
                        if !pageText.isEmpty {
                            combinedText.append(pageText)
                        }
                    }
                }
                if !combinedText.isEmpty {
                    return combinedText.joined(separator: "\n")
                }
            }
        }

        if let image = NSImage(contentsOf: url) {
            return try await imageProcessor.recognizeText(image)
        }

        return ""
    }

    private func createEvent(from suggestion: DocumentActionSuggestion) async throws {
        guard let date = suggestion.date else { return }

        let granted = try await requestCalendarAccess()
        guard granted else { throw DocumentActionServiceError.calendarAccessDenied }

        let event = EKEvent(eventStore: eventStore)
        event.title = suggestion.title
        event.startDate = date
        event.endDate = date.addingTimeInterval(suggestion.duration ?? 3600)
        event.calendar = eventStore.defaultCalendarForNewEvents

        try eventStore.save(event, span: .thisEvent)
    }

    private func createContact(from suggestion: DocumentActionSuggestion) async throws {
        let granted = try await requestContactsAccess()
        guard granted else { throw DocumentActionServiceError.contactsAccessDenied }

        let contact = CNMutableContact()
        if let contactName = suggestion.contactName, contactName != "New Contact" {
            let parts = contactName.split(separator: " ")
            if let first = parts.first {
                contact.givenName = String(first)
            }
            if parts.count > 1 {
                contact.familyName = parts.dropFirst().joined(separator: " ")
            }
        }

        if let email = suggestion.email {
            contact.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: email as NSString)]
        }

        if let phone = suggestion.phone {
            contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMain, value: CNPhoneNumber(stringValue: phone))]
        }

        if let address = suggestion.address {
            let postal = CNMutablePostalAddress()
            postal.street = address
            contact.postalAddresses = [CNLabeledValue(label: CNLabelWork, value: postal)]
        }

        let request = CNSaveRequest()
        request.add(contact, toContainerWithIdentifier: nil)
        try contactStore.execute(request)
    }

    private func requestCalendarAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            if #available(macOS 14.0, *) {
                eventStore.requestFullAccessToEvents { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            } else {
                eventStore.requestAccess(to: .event) { granted, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }

    private func requestContactsAccess() async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            contactStore.requestAccess(for: .contacts) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }
    #endif
}

enum DocumentActionServiceError: LocalizedError {
    case calendarAccessDenied
    case contactsAccessDenied

    var errorDescription: String? {
        switch self {
        case .calendarAccessDenied:
            return "Calendar access was denied"
        case .contactsAccessDenied:
            return "Contacts access was denied"
        }
    }
}
