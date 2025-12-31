//
//  QueuedScan.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

import Foundation

enum ScanStatus: Codable, Equatable {
    case pending
    case scanning
    case processing
    case completed
    case failed(String)

    var description: String {
        switch self {
        case .pending: return "Pending"
        case .scanning: return "Scanning..."
        case .processing: return "Processing..."
        case .completed: return "Completed"
        case .failed(let error): return "Failed: \(error)"
        }
    }
}

struct QueuedScan: Identifiable, Codable {
    let id: UUID
    var name: String
    var preset: ScanPreset
    var status: ScanStatus
    var progress: Double // 0-1
    var estimatedFileSize: Int64?
    var thumbnailData: Data?

    init(
        id: UUID = UUID(),
        name: String,
        preset: ScanPreset,
        status: ScanStatus = .pending,
        progress: Double = 0,
        estimatedFileSize: Int64? = nil,
        thumbnailData: Data? = nil
    ) {
        self.id = id
        self.name = name
        self.preset = preset
        self.status = status
        self.progress = progress
        self.estimatedFileSize = estimatedFileSize
        self.thumbnailData = thumbnailData
    }
}
