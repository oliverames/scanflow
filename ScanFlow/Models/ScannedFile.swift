//
//  ScannedFile.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

public struct ScannedFile: Identifiable, Codable {
    public let id: UUID
    public var filename: String
    public var fileURL: URL
    public var size: Int64 // bytes
    public var resolution: Int
    public var dateScanned: Date
    public var scannerModel: String
    public var format: ScanFormat
    public var thumbnailPath: String?

    public init(
        id: UUID = UUID(),
        filename: String,
        fileURL: URL,
        size: Int64,
        resolution: Int,
        dateScanned: Date = Date(),
        scannerModel: String,
        format: ScanFormat,
        thumbnailPath: String? = nil
    ) {
        self.id = id
        self.filename = filename
        self.fileURL = fileURL
        self.size = size
        self.resolution = resolution
        self.dateScanned = dateScanned
        self.scannerModel = scannerModel
        self.format = format
        self.thumbnailPath = thumbnailPath
    }

    public var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dateScanned)
    }
}
