//
//  File.swift
//  
//
//  Created by Jakub Dolejs on 25/10/2023.
//

import Foundation
import CoreMedia
import Accelerate
import ImageIO

/// Adds ``ImageConvertible`` protocol conformance to ``CoreMedia/CMSampleBuffer``
extension CMSampleBuffer: ImageConvertible {
    
    /// Convert the sample buffer to ``Image``
    /// - Returns: Image derived from the sample buffer
    /// - Since: 1.0.0
    public func convertToImage() throws -> Image {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(self) else {
            throw ImageError.imageConversionFailed
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
        }
        guard let data = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            throw ImageError.imageConversionFailed
        }
        let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
        let imageFormat: ImageFormat
        switch format {
        case kCVPixelFormatType_32ABGR:
            imageFormat = .abgr
        case kCVPixelFormatType_32ARGB:
            imageFormat = .argb
        case kCVPixelFormatType_32BGRA:
            imageFormat = .bgra
        case kCVPixelFormatType_32RGBA:
            imageFormat = .rgba
        case kCVPixelFormatType_24BGR:
            imageFormat = .bgr
        case kCVPixelFormatType_24RGB:
            imageFormat = .rgb
        case kCVPixelFormatType_OneComponent8:
            imageFormat = .grayscale
        default:
            throw ImageError.imageConversionFailed
        }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let length = CVPixelBufferGetDataSize(pixelBuffer)
        let uint8ptr = data.bindMemory(to: UInt8.self, capacity: length)
        
        return Image(data: Data(buffer: UnsafeBufferPointer<UInt8>(start: uint8ptr, count: length)), width: width, height: height, bytesPerRow: rowBytes, format: imageFormat)
    }
    
    /// Convert the sample buffer to ``CoreGraphics/CGImage``
    /// - Returns: Image derived from the sample buffer
    /// - Since: 1.0.0
    public func convertToCGImage() throws -> CGImage {
        fatalError("Method not implemented")
    }
    
    var size: CGSize {
        get throws {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(self) else {
                throw ImageError.imageConversionFailed
            }
            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
            return CGSize(width: width, height: height)
        }
    }
}
