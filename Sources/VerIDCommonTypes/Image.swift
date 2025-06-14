//
//  File.swift
//  
//
//  Created by Jakub Dolejs on 23/10/2023.
//

import Foundation
import CoreGraphics
import Accelerate
#if canImport(UIKit)
import UIKit
#endif

import AVFoundation
import ImageIO
import CoreImage
import MobileCoreServices
import UIKit

public struct Image: Hashable, @unchecked Sendable {
    
    public let videoBuffer: CVPixelBuffer
    public let depthData: AVDepthData?
    public var width: Int {
        CVPixelBufferGetWidth(self.videoBuffer)
    }
    public var height: Int {
        CVPixelBufferGetHeight(self.videoBuffer)
    }
    public var size: CGSize {
        CGSize(width: self.width, height: self.height)
    }
    
    // Initializer with CVPixelBuffer and optional AVDepthData
    public init(videoBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation = .up, depthData: AVDepthData? = nil) {
        // Correct the orientation if needed and store corrected version
        self.videoBuffer = Image.correctOrientation(pixelBuffer: videoBuffer, orientation: orientation)
        self.depthData = depthData?.applyingExifOrientation(orientation)
    }
    
    // Initializer with HEIC byte array
    public init?(heicData: Data) {
        guard let imageSource = CGImageSourceCreateWithData(heicData as CFData, nil) else {
            return nil
        }
        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return nil
        }
        var orientation: CGImagePropertyOrientation = .up
        if let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any], let orientationValue = imageProperties[kCGImagePropertyOrientation] as? UInt32, let o = CGImagePropertyOrientation(rawValue: orientationValue) {
            orientation = o
        }
        let ciImage = CIImage(cgImage: cgImage).oriented(orientation)
        guard let buffer = Image.createCVPixelBuffer(from: ciImage) else {
            return nil
        }
        self.videoBuffer = buffer
        if let depthAuxDataInfo = CGImageSourceCopyAuxiliaryDataInfoAtIndex(imageSource, 0, kCGImageAuxiliaryDataTypeDepth as CFString) as? [AnyHashable: Any],
              let depthData = try? AVDepthData(fromDictionaryRepresentation: depthAuxDataInfo) {
            if orientation != .up {
                self.depthData = depthData.applyingExifOrientation(orientation)
            } else {
                self.depthData = depthData
            }
        } else {
            self.depthData = nil
        }
    }
    
    public init?(cgImage: CGImage, orientation: CGImagePropertyOrientation = .up, depthData: AVDepthData? = nil) {
        let ciImage = CIImage(cgImage: cgImage).oriented(orientation)
        guard let buffer = Image.createCVPixelBuffer(from: ciImage) else {
            return nil
        }
        self.videoBuffer = buffer
        self.depthData = depthData?.applyingExifOrientation(orientation)
    }
    
    // Method to persist the Image in HEIC format
    public func toHEIC() -> Data? {
        let data = NSMutableData()
        let pixelBuffer = self.videoBuffer
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, AVFileType.heic as CFString, 1, nil), let cgImage = Image.createCGImage(from: pixelBuffer) else {
            return nil
        }
        // Add the main image to the destination
        let properties: CFDictionary = [:] as CFDictionary
        CGImageDestinationAddImage(destination, cgImage, properties)
        // Add depth data if available
        if let depthData = depthData {
            var auxDataType: NSString? = nil
            if let depthDict = depthData.dictionaryRepresentation(forAuxiliaryDataType: &auxDataType) {
                CGImageDestinationAddAuxiliaryDataInfo(destination, auxDataType!, depthDict as CFDictionary)
            }
        }
        // Finalize the destination to write to data
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return data as Data
    }
    
    public func toCGImage() -> CGImage? {
        return Image.createCGImage(from: self.videoBuffer)
    }
    
    private func imageCoordinatesToDepthCoordinates(x: Int, y: Int) -> (Int, Int)? {
        guard let depthData = self.depthData, let cameraCalibrationData = depthData.cameraCalibrationData else {
            return nil
        }
        let referenceDimensions = cameraCalibrationData.intrinsicMatrixReferenceDimensions
        let rotatedX: CGFloat = CGFloat(x)
        let rotatedY: CGFloat = CGFloat(y)
        var imageWidth: CGFloat = CGFloat(self.width)
        var imageHeight: CGFloat = CGFloat(self.height)
        let normX = rotatedX / imageWidth * referenceDimensions.width
        let normY = rotatedY / imageHeight * referenceDimensions.height
        let depthMapWidth = CGFloat(CVPixelBufferGetWidth(depthData.depthDataMap))
        let depthMapHeight = CGFloat(CVPixelBufferGetHeight(depthData.depthDataMap))
        let depthX = Int(normX / referenceDimensions.width * depthMapWidth)
        let depthY = Int(normY / referenceDimensions.height * depthMapHeight)
        return (depthX, depthY)
    }
    
    public func coordinates3dAt(x: Int, y: Int) -> simd_float3? {
        guard let depthData = self.depthData else {
            return nil
        }
        guard let cameraCalibrationData = depthData.cameraCalibrationData else {
            return nil
        }
        guard let (depthX, depthY) = self.imageCoordinatesToDepthCoordinates(x: x, y: y) else {
            return nil
        }
        let depthDataMap = depthData.depthDataMap
        CVPixelBufferLockBaseAddress(depthDataMap, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(depthDataMap, .readOnly)
        }
        let width = CVPixelBufferGetWidth(depthDataMap)
        let height = CVPixelBufferGetHeight(depthDataMap)
        guard depthX >= 0, depthX < width, depthY >= 0, depthY < height else {
            return nil
        }
        guard let baseAddress = CVPixelBufferGetBaseAddress(depthDataMap)?.assumingMemoryBound(to: Float32.self) else {
            return nil
        }
        let fx = cameraCalibrationData.intrinsicMatrix[0][0]
        let fy = cameraCalibrationData.intrinsicMatrix[1][1]
        let cx = cameraCalibrationData.intrinsicMatrix[2][0]
        let cy = cameraCalibrationData.intrinsicMatrix[2][1]
        
        let depth = baseAddress[depthY * width + depthX]
        guard depth > 0, !depth.isNaN else {
            return nil
        }
        var X_camera = (Float(depthX) - cx) * depth / fx
        var Y_camera = (Float(depthY) - cy) * depth / fy
        let Z_camera = depth
        return simd_float3(X_camera, Y_camera, Z_camera)
    }
    
    //MARK: - Hashable
    
    public func hash(into hasher: inout Hasher) {
        // Hash important properties like width, height, and a portion of the pixel buffer data
        hasher.combine(width)
        hasher.combine(height)
        
        CVPixelBufferLockBaseAddress(videoBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(videoBuffer, .readOnly) }
        
        if let baseAddress = CVPixelBufferGetBaseAddress(videoBuffer) {
            let byteCount = min(64, CVPixelBufferGetDataSize(videoBuffer)) // Hash the first 64 bytes for performance
            let buffer = UnsafeBufferPointer(start: baseAddress.assumingMemoryBound(to: UInt8.self), count: byteCount)
            for byte in buffer {
                hasher.combine(byte)
            }
        }
    }
    
    //MARK: -
    
    // Correct the orientation for CVPixelBuffer
    private static func correctOrientation(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> CVPixelBuffer {
        if orientation == .up {
            return pixelBuffer
        }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
        guard let correctedBuffer = Image.createCVPixelBuffer(from: ciImage) else {
            return pixelBuffer
        }
        return correctedBuffer
    }
    
    private static func revertOrientation(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> CVPixelBuffer {
        let reverseOrientation: CGImagePropertyOrientation
        switch orientation {
        case .up:
            return pixelBuffer
        case .left:
            reverseOrientation = .right
        case .right:
            reverseOrientation = .left
        case .leftMirrored:
            reverseOrientation = .rightMirrored
        case .rightMirrored:
            reverseOrientation = .leftMirrored
        default:
            reverseOrientation = orientation
        }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(reverseOrientation)
        guard let revertedBuffer = Image.createCVPixelBuffer(from: ciImage) else {
            return pixelBuffer
        }
        return revertedBuffer
    }
    
    private static func createCGImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        return context.createCGImage(ciImage, from: ciImage.extent)
    }
    
    private static func createCVPixelBuffer(from ciImage: CIImage) -> CVPixelBuffer? {
        let width = Int(ciImage.extent.width)
        let height = Int(ciImage.extent.height)
        
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            pixelBufferAttributes as CFDictionary,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        let context = CIContext()
        context.render(ciImage, to: buffer)
        
        return buffer
    }
}
