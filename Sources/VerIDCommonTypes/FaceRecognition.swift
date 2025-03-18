//
//  FaceRecognition.swift
//
//
//  Created by Jakub Dolejs on 23/02/2024.
//

import Foundation

public protocol FaceRecognition {
    associatedtype FaceTemplate: Codable, Hashable, Sendable
    
    func createFaceRecognitionTemplates(from faces: [Face], in image: Image) throws -> [FaceTemplate]
    
    func compareFaceRecognitionTemplates(_ faceRecognitionTemplates: [FaceTemplate], to template: FaceTemplate) throws -> [Float]
}
