//
//  ScanMetadata.swift
//  ScanFlow
//
//  Created by Claude on 2024-12-30.
//

import Foundation

public struct ScanMetadata: Codable {
    public let resolution: Int
    public let colorSpace: String
    public let timestamp: Date
    public let scannerModel: String
    public let width: Int?
    public let height: Int?
    public let bitDepth: Int?

    public init(
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
