//
//  FaceDetection.swift
//
//
//  Created by Jakub Dolejs on 23/10/2023.
//

import Foundation

/// Face detection protocol
/// - Since: 1.0.0
public protocol FaceDetection {
    
    /// Detect a face in image
    /// - Parameters:
    ///   - image: Image in which to detect the face
    ///   - limit: Maximum number of faces to detect
    /// - Returns: Array of detected faces
    /// - Since: 1.0.0
    func detectFacesInImage(_ image: Image, limit: Int) throws -> [Face]
}
