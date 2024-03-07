//
//  FaceRecognitionTemplate.swift
//
//
//  Created by Jakub Dolejs on 23/02/2024.
//

import Foundation

public struct FaceRecognitionTemplate: Hashable, Sendable, Codable {
    
    public let version: Int
    public let data: Data
}
