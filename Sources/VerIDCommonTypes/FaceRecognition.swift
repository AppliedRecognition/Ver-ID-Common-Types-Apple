//
//  FaceRecognition.swift
//
//
//  Created by Jakub Dolejs on 23/02/2024.
//

import Foundation

public protocol FaceRecognition {
    associatedtype FaceTemplate: Codable, Hashable, Sendable
    
    @available(*, deprecated, message: "Use async method")
    /// Create face recognition templates
    /// - Parameters:
    ///   - faces: Faces from which to extract the face templates
    ///   - image: Image in which the faces were detected
    /// - Returns: Array of face templates
    /// - Deprecated: This method is deprecated in version 1.4.0 in favour of its async counterpart
    /// - SeeAlso: ``createFaceRecognitionTemplates(from:in:)-9azpt``
    func createFaceRecognitionTemplates(from faces: [Face], in image: Image) throws -> [FaceTemplate]
    
    /// Create face recognition templates
    /// - Parameters:
    ///   - faces: Faces from which to extract the face templates
    ///   - image: Image in which the faces were detected
    /// - Returns: Array of face templates
    /// - Since: 1.4.0
    func createFaceRecognitionTemplates(from faces: [Face], in image: Image) async throws -> [FaceTemplate]
    
    func compareFaceRecognitionTemplates(_ faceRecognitionTemplates: [FaceTemplate], to template: FaceTemplate) throws -> [Float]
}

public extension FaceRecognition {
    
    func createFaceRecognitionTemplates(from faces: [Face], in image: Image) async throws -> [FaceTemplate] {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global().async {
                do {
                    let result = try self.createFaceRecognitionTemplates(from: faces, in: image)
                    cont.resume(returning: result)
                } catch {
                    cont.resume(throwing: error)
                }
            }
        }
    }
    
    /// Helper function to streamline the implementation of the synchronous version of createFaceRecognitionTemplates
    /// - Parameters:
    ///   - faces: Faces for which to extract templates
    ///   - image: Image in which the faces were detected
    /// - Returns: Array of face templates
    func createFaceRecognitionTemplatesSync(from faces: [Face], in image: Image) throws -> [FaceTemplate] {
        let result = TemplateExtractionResult<FaceTemplate>()
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            do {
                let value = try await self.createFaceRecognitionTemplates(from: faces, in: image)
                result.result = .success(value)
            } catch {
                result.result = .failure(error)
            }
            semaphore.signal()
        }
        semaphore.wait()
        return try result.result.get()
    }
}

fileprivate class TemplateExtractionResult<T> {
    var result: Result<[T],Error>! = nil
}
