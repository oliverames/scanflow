//
//  ScanMetadata.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

import Foundation

struct ScanMetadata: Codable {
    let resolution: Int
    let colorSpace: String
    let timestamp: Date
    let scannerModel: String
    let width: Int?
    let height: Int?
    let bitDepth: Int?

    init(
        resolution: Int,
        colorSpace: String = "sRGB",
        timestamp: Date = Date(),
        scannerModel: String,
        width: Int? = nil,
        height: Int? = nil,
        bitDepth: Int? = nil
    ) {
        self.resolution = resolution
        self.colorSpace = colorSpace
        self.timestamp = timestamp
        self.scannerModel = scannerModel
        self.width = width
        self.height = height
        self.bitDepth = bitDepth
    }
}
