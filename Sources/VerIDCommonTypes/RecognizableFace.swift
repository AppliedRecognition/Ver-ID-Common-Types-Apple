//
//  RecognizableFace.swift
//
//
//  Created by Jakub Dolejs on 23/02/2024.
//

import Foundation

public struct RecognizableFace: Hashable, Sendable, Codable {
    
    let face: Face
    let template: FaceRecognitionTemplate
}
