//
//  AnyFacialAttributeDetector.swift
//  
//
//  Created by Jakub Dolejs on 16/09/2025.
//

import Foundation

public struct AnyFacialAttributeDetector {
    
    private let _detect: (Face, Image) async throws -> AnyFacialAttributeDetectionResult?
    private let _getThreshold: () -> Float
    private let _setThreshold: (Float) -> Void
    
    public var confidenceThreshold: Float {
        get { _getThreshold() }
        set { _setThreshold(newValue) }
    }
    
    public init<D: FacialAttributeDetection>(_ detector: D) {
        var mutableDetector = detector
        _detect = { face, image in
            try await mutableDetector.detect(in: face, image: image)?.typeErased
        }
        _getThreshold = { mutableDetector.confidenceThreshold }
        _setThreshold = { mutableDetector.confidenceThreshold = $0 }
    }
    
    public func detect(in face: Face, image: Image) async throws -> AnyFacialAttributeDetectionResult? {
        try await _detect(face, image)
    }
}

public struct AnyFacialAttributeDetectionResult {
    public let confidence: Float
    public let type: AnyHashable
    public let typeDescription: String
}

extension AnyFacialAttributeDetectionResult: CustomStringConvertible {
    public var description: String {
        String(format: "%@: %.02f", self.typeDescription, self.confidence)
    }
}

public extension AnyFacialAttributeDetectionResult {
    func asType<T>(_ type: T.Type) -> T? {
        self.type.base as? T
    }
}
