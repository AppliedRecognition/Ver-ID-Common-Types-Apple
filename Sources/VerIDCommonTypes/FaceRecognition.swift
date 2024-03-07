//
//  FaceRecognition.swift
//
//
//  Created by Jakub Dolejs on 23/02/2024.
//

import Foundation

public protocol FaceRecognition {
    
    func createFaceRecognitionTemplates(from faces: [Face], in image: Image) throws -> [FaceRecognitionTemplate]
    
    func compareFaceRecognitionTemplates(_ faceRecognitionTemplates: [FaceRecognitionTemplate], to template: FaceRecognitionTemplate) throws -> Float
}
