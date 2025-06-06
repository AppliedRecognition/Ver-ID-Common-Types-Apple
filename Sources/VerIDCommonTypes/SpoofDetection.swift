//
//  SpoofDetection.swift
//
//
//  Created by Jakub Dolejs on 06/06/2025.
//

import Foundation

public protocol SpoofDetection {
    
    func detectSpoofInImage(_ image: Image, regionOfInterest: CGRect?) async throws -> Float
}
