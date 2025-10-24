//
//  ImageTests.swift
//  VerIDCommonTypes
//
//  Created by Jakub Dolejs on 23/10/2025.
//

import Foundation
import Testing
import UIKit
@testable import VerIDCommonTypes

struct ImageTests {

    @Test func testCreateImageFromUIImage() throws {
        let uiImage = try self.createUIImage()
        _ = try uiImage.toVerIDImage()
    }

    @Test func testCreateImageFromCGImage() throws {
        let uiImage = try self.createUIImage()
        guard let cgImage = uiImage.cgImage else {
            throw TestError.genericError
        }
        let image = Image(cgImage: cgImage, orientation: uiImage.imageOrientation.cgImagePropertyOrientation)
        #expect(image != nil)
    }
    
    @Test(.disabled("Run as needed"), arguments: ["up", "right", "down", "left", "upMirrored", "rightMirrored", "downMirrored", "leftMirrored"])
    func createImageWithOrientation(orientationStr: String) throws {
        guard let orientation = UIImage.Orientation.fromString(orientationStr) else {
            throw TestError.genericError
        }
        let cgImage = try createUIImage(orientation: orientation)
        let image = UIImage(cgImage: cgImage)
        if let original = image.jpegData(compressionQuality: 0.9) {
            Attachment.record(original, named: "original-raw.jpg")
        }
        let originalCorrected = UIImage(cgImage: cgImage, scale: 1, orientation: orientation.upright)
        if let original = originalCorrected.jpegData(compressionQuality: 0.9) {
            Attachment.record(original, named: "original-corrected.jpg")
        }
        let veridImage = try originalCorrected.toVerIDImage()
        if let converted = veridImage.toUIImage(), let jpeg = converted.jpegData(compressionQuality: 0.9) {
            Attachment.record(jpeg, named: "converted.jpg")
        }
    }
    
    @Test("Create images repeatedly")
    func createImagesRepeatedly() throws {
        let uiImage = try self.createUIImage()
        for _ in 0..<1000 {
            _ = try uiImage.toVerIDImage()
        }
    }
    
    private func createUIImage() throws -> UIImage {
        guard let url = Bundle.module.url(forResource: "Image", withExtension: "heic") else {
            throw TestError.genericError
        }
        let data = try Data(contentsOf: url)
        guard let uiImage = UIImage(data: data) else {
            throw TestError.genericError
        }
        return uiImage
    }
    
    private func createUIImage(orientation: UIImage.Orientation) throws -> CGImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let original = try self.createUIImage()
        let uprightOriginal = UIGraphicsImageRenderer(size: original.size, format: format).image { ctx in
            original.draw(at: .zero)
        }
        let originalWithMetaRotation = UIImage(cgImage: uprightOriginal.cgImage!, scale: 1, orientation: orientation)
        let rendered = UIGraphicsImageRenderer(size: originalWithMetaRotation.size, format: format).image { ctx in
            originalWithMetaRotation.draw(at: .zero)
        }
        guard let cgImage = rendered.cgImage else {
            throw TestError.genericError
        }
        return cgImage
    }
}

extension UIImage.Orientation: @retroactive CustomStringConvertible {
    var opposite: UIImage.Orientation {
        switch self {
        case .up: return .down
        case .right: return .left
        case .down: return .up
        case .left: return .right
        case .upMirrored: return .downMirrored
        case .rightMirrored: return .leftMirrored
        case .downMirrored: return .upMirrored
        case .leftMirrored: return .rightMirrored
        @unknown default:
            return .down
        }
    }
    var upright: UIImage.Orientation {
        switch self {
        case .up, .upMirrored, .down, .downMirrored, .leftMirrored, .rightMirrored: return self
        case .left, .right: return self.opposite
        @unknown default:
            return self
        }
    }
    public var description: String {
        switch self {
        case .up: return "up"
        case .down: return "down"
        case .left: return "left"
        case .right: return "right"
        case .upMirrored: return "upMirrored"
        case .downMirrored: return "downMirrored"
        case .leftMirrored: return "leftMirrored"
        case .rightMirrored: return "rightMirrored"
        @unknown default: return "unknown(\(rawValue))"
        }
    }
    static func fromString(_ string: String) -> UIImage.Orientation? {
        switch string {
        case "up": return .up
        case "down": return .down
        case "left": return .left
        case "right": return .right
        case "upMirrored": return .upMirrored
        case "downMirrored": return .downMirrored
        case "leftMirrored": return .leftMirrored
        case "rightMirrored": return .rightMirrored
        default: return nil
        }
    }
}
