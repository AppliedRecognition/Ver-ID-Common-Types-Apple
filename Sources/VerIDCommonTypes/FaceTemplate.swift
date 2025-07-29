//
//  FaceTemplate.swift
//
//
//  Created by Jakub Dolejs on 12/06/2025.
//

import Foundation

public protocol FaceTemplateProtocol: Hashable, Sendable, Codable {
    var version: Int { get }
}

public struct FaceTemplate<Version: FaceTemplateVersion, TemplateData: FaceTemplateData>: FaceTemplateProtocol {
    
    private enum CodingKeys: String, CodingKey {
        case version
        case data
    }
    
    public let data: TemplateData
    public var version: Int {
        return Version.id
    }
    
    public init(data: TemplateData) {
        self.data = data
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let versionId = try container.decode(Int.self, forKey: .version)
        guard versionId == Version.id else {
            throw DecodingError.dataCorruptedError(forKey: .version, in: container, debugDescription: "Version mismatch. Expected \(Version.id), got \(versionId)")
        }
        self.data = try container.decode(TemplateData.self, forKey: .data)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(Version.id, forKey: .version)
        try container.encode(self.data, forKey: .data)
    }
}

extension Array: FaceTemplateData where Element: Hashable & Codable {}

public protocol FaceTemplateVersion: Hashable, Sendable, Codable {
    static var id: Int { get }
}
public protocol FaceTemplateData: Hashable, Sendable, Codable {}
