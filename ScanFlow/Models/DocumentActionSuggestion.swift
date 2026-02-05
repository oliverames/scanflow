//
//  DocumentActionSuggestion.swift
//  ScanFlow
//
//  Models for suggested actions derived from scanned document content.
//

import Foundation

enum DocumentActionKind: String, Codable, CaseIterable {
    case event
    case contact
}

struct DocumentActionSuggestion: Identifiable, Equatable {
    let id: UUID
    let kind: DocumentActionKind
    let title: String
    let subtitle: String
    let date: Date?
    let duration: TimeInterval?
    let contactName: String?
    let email: String?
    let phone: String?
    let address: String?

    init(
        id: UUID = UUID(),
        kind: DocumentActionKind,
        title: String,
        subtitle: String,
        date: Date? = nil,
        duration: TimeInterval? = nil,
        contactName: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        address: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.date = date
        self.duration = duration
        self.contactName = contactName
        self.email = email
        self.phone = phone
        self.address = address
    }
}
