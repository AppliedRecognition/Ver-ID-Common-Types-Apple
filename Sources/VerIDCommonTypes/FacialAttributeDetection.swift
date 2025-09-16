//
//  FacialAttributeDetection.swift
//
//
//  Created by Jakub Dolejs on 16/09/2025.
//

import Foundation

public protocol FacialAttributeDetection {
    associatedtype AttributeType: Hashable & RawRepresentable where AttributeType.RawValue == String
    var confidenceThreshold: Float { get set }
    func detect(in face: Face, image: Image) async throws -> FacialAttributeDetectionResult<AttributeType>?
}

public struct FacialAttributeDetectionResult<T> where T: Hashable & RawRepresentable, T.RawValue == String {
    public let confidence: Float
    public let type: T
    public init(confidence: Float, type: T) {
        self.confidence = confidence
        self.type = type
    }
}

public extension FacialAttributeDetection {
    
    var typeErased: AnyFacialAttributeDetector {
        return AnyFacialAttributeDetector(self)
    }
}

public extension FacialAttributeDetectionResult {
    
    var typeErased: AnyFacialAttributeDetectionResult {
        return AnyFacialAttributeDetectionResult(confidence: self.confidence, type: AnyHashable(self.type), typeDescription: self.type.rawValue)
    }
}

extension FacialAttributeDetectionResult: CustomStringConvertible {
    public var description: String {
        String(format: "%@: %.02f", self.type.rawValue, self.confidence)
    }
}
