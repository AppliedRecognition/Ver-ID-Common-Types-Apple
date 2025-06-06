//
//  SpoofDetection.swift
//
//
//  Created by Jakub Dolejs on 06/06/2025.
//

import Foundation

public protocol SpoofDetection {
    
    var confidenceThreshold: Float { get set }
    
    func detectSpoofInImage(_ image: Image, regionOfInterest: CGRect?) async throws -> Float
}

public extension SpoofDetection {
    
    func isSpoofInImage(_ image: Image, regionOfInterest: CGRect?) async throws -> Bool {
        let score = try await self.detectSpoofInImage(image, regionOfInterest: regionOfInterest)
        return score > self.confidenceThreshold
    }
}
