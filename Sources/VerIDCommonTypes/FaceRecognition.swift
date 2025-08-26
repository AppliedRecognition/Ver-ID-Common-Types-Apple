//
//  FaceRecognition.swift
//
//
//  Created by Jakub Dolejs on 23/02/2024.
//

import Foundation

public protocol FaceRecognition {
    associatedtype Version: FaceTemplateVersion
    associatedtype TemplateData: FaceTemplateData
    
    var version: Int { get }
    
    var defaultThreshold: Float { get }
    
    /// Create face recognition templates
    /// - Parameters:
    ///   - faces: Faces from which to extract the face templates
    ///   - image: Image in which the faces were detected
    /// - Returns: Array of face templates
    /// - Since: 1.4.0
    func createFaceRecognitionTemplates(from faces: [Face], in image: Image) async throws -> [FaceTemplate<Version,TemplateData>]
    
    /// Compare face recognition templates
    /// - Parameters:
    ///   - faceRecognitionTemplates: The templates to compare
    ///   - template: The template to compare the templates to
    /// - Returns: Array of comparison scores of the template against the templates
    func compareFaceRecognitionTemplates(_ faceRecognitionTemplates: [FaceTemplate<Version,TemplateData>], to template: FaceTemplate<Version,TemplateData>) async throws -> [Float]
}

public extension FaceRecognition {
    var version: Int { Version.id }
}
