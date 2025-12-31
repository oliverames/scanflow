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

struct ScannedFile: Identifiable, Codable {
    let id: UUID
    var filename: String
    var fileURL: URL
    var size: Int64 // bytes
    var resolution: Int
    var dateScanned: Date
    var scannerModel: String
    var format: ScanFormat
    var thumbnailPath: String?

    init(
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

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dateScanned)
    }
}
