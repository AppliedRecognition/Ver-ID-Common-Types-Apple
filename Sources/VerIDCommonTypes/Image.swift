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
        if let dd = self.depthData {
            var auxDataType: NSString? = nil
            if let dict = dd.dictionaryRepresentation(forAuxiliaryDataType: &auxDataType), let md = dict[kCGImageAuxiliaryDataInfoMetadata] {
                let metadata = md as! CGImageMetadata
                NSLog("=============")
                CGImageMetadataEnumerateTagsUsingBlock(metadata, nil, nil) { path, tag in
                    let tagType = CGImageMetadataTagGetType(tag)
                    let name = CGImageMetadataTagCopyName(tag) as String? ?? ""
                    let prefix = CGImageMetadataTagCopyPrefix(tag) as String? ?? ""
                    let namespace = CGImageMetadataTagCopyNamespace(tag) as String? ?? ""
                    let tagTypeStr: String
                    switch tagType {
                    case .invalid:
                        tagTypeStr = "invalid"
                    case .default:
                        tagTypeStr = "default"
                    case .alternateArray:
                        tagTypeStr = "alternate array"
                    case .alternateText:
                        tagTypeStr = "alternate text"
                    case .arrayOrdered:
                        tagTypeStr = "array ordered"
                    case .arrayUnordered:
                        tagTypeStr = "array unordered"
                    case .string:
                        tagTypeStr = "string"
                    case .structure:
                        tagTypeStr = "structure"
                    @unknown default:
                        tagTypeStr = "unknown"
                    }
                    let nsConst: String
                    switch namespace as CFString {
                    case kCGImageMetadataNamespaceExif:
                        nsConst = "kCGImageMetadataNamespaceExif"
                    case kCGImageMetadataNamespaceTIFF:
                        nsConst = "kCGImageMetadataNamespaceTIFF"
                    case kCGImageMetadataNamespaceExifEX:
                        nsConst = "kCGImageMetadataNamespaceExifEX"
                    case kCGImageMetadataNamespaceExifAux:
                        nsConst = "kCGImageMetadataNamespaceExifAux"
                    case kCGImageMetadataNamespacePhotoshop:
                        nsConst = "kCGImageMetadataNamespacePhotoshop"
                    case kCGImageMetadataNamespaceIPTCCore:
                        nsConst = "kCGImageMetadataNamespaceIPTCCore"
                    case kCGImageMetadataNamespaceXMPBasic:
                        nsConst = "kCGImageMetadataNamespaceXMPBasic"
                    case kCGImageMetadataNamespaceXMPRights:
                        nsConst = "kCGImageMetadataNamespaceXMPRights"
                    case kCGImageMetadataNamespaceDublinCore:
                        nsConst = "kCGImageMetadataNamespaceDublinCore"
                    case kCGImageMetadataNamespaceIPTCExtension:
                        nsConst = "kCGImageMetadataNamespaceIPTCExtension"
                    default:
                        nsConst = "unknown namespace constant"
                    }
                    let prefixConst: String
                    switch prefix as CFString {
                    case kCGImageMetadataPrefixExif:
                        prefixConst = "kCGImageMetadataPrefixExif"
                    case kCGImageMetadataPrefixTIFF:
                        prefixConst = "kCGImageMetadataPrefixTIFF"
                    case kCGImageMetadataPrefixExifEX:
                        prefixConst = "kCGImageMetadataPrefixExifEX"
                    case kCGImageMetadataPrefixExifAux:
                        prefixConst = "kCGImageMetadataPrefixExifAux"
                    case kCGImageMetadataPrefixPhotoshop:
                        prefixConst = "kCGImageMetadataPrefixPhotoshop"
                    case kCGImageMetadataPrefixIPTCCore:
                        prefixConst = "kCGImageMetadataPrefixIPTCCore"
                    case kCGImageMetadataPrefixXMPBasic:
                        prefixConst = "kCGImageMetadataPrefixXMPBasic"
                    case kCGImageMetadataPrefixXMPRights:
                        prefixConst = "kCGImageMetadataPrefixXMPRights"
                    case kCGImageMetadataPrefixDublinCore:
                        prefixConst = "kCGImageMetadataPrefixDublinCore"
                    case kCGImageMetadataPrefixIPTCExtension:
                        prefixConst = "kCGImageMetadataPrefixIPTCExtension"
                    default:
                        prefixConst = "unknown prefix constant"
                    }
                    return true
                }
            }
        }
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









//MARK: - Old image type

/// Image type used by Ver-ID libraries
/// - Since: 1.0.0
public struct ImageOld: Hashable, Sendable, Codable {
    
    /// Image pixel data
    ///
    /// The pixel layout depends on ``format``
    /// - Since: 1.0.0
    public var data: Data
    /// Width of the image in pixels
    /// - Since: 1.0.0
    public var width: Int
    /// Height of the image in pixels
    /// - Since: 1.0.0
    public var height: Int
    /// Bytes per row of pixels
    /// - Since: 1.0.0
    public var bytesPerRow: Int
    /// Image format
    /// - Since: 1.0.0
    public let format: ImageFormat
    /// Image size
    /// - Since: 1.0.0
    public var size: CGSize {
        .init(width: self.width, height: self.height)
    }
    
    /// Constructor
    /// - Parameters:
    ///   - data: Image pixel data
    ///   - width: Image width in pixels
    ///   - height: Image height in pixels
    ///   - bytesPerRow: Bytes per row of pixels
    ///   - format: Image format
    /// - Since: 1.0.0
    public init(data: Data, width: Int, height: Int, bytesPerRow: Int, format: ImageFormat) {
        self.data = data
        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
        self.format = format
    }
    
    /// ``ImageConvertible`` implementation
    /// - Returns: Itself
    /// - Since: 1.0.0
    public func convertToImage() throws -> ImageOld {
        self
    }
    
    /// Convert the image to ``CGImage``
    /// - Returns: The image converted to ``CGImage``
    /// - Throws: ``ImageError``
    /// - Since: 1.0.0
    public func convertToCGImage() throws -> CGImage {
        var data = [UInt8](self.data)
        let dataPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
        dataPointer.initialize(from: &data, count: data.count)
        let src = vImage_Buffer(data: dataPointer, height: UInt(self.height), width: UInt(self.width), rowBytes: self.bytesPerRow)
        defer {
            src.free()
        }
        let bitmapInfo: CGBitmapInfo
        var bitsPerPixel: UInt32 = 24
        switch self.format {
        case .abgr:
            bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue)
        case .argb:
            bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue)
        case .bgra:
            bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue)
        case .rgba:
            bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.noneSkipLast.rawValue)
        case .rgb:
            bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.none.rawValue)
        case .bgr:
            bitmapInfo = CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.none.rawValue)
        default:
            bitsPerPixel = 8
            bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        }
//        var colorSpace: Unmanaged<CGColorSpace> = Unmanaged.passRetained(CGColorSpaceCreateDeviceRGB())
        let cgImageFormat = vImage_CGImageFormat(bitsPerComponent: 8, bitsPerPixel: bitsPerPixel, colorSpace: nil, bitmapInfo: bitmapInfo, version: 0, decode: nil, renderingIntent: .defaultIntent)
        return try src.createCGImage(format: cgImageFormat)
    }
    
    /// Apply the given orientation to the image
    /// - Parameter orientation: Orientation
    /// - Throws: ``ImageError``
    /// - Since: 1.0.0
    public mutating func applyOrientation(_ orientation: CGImagePropertyOrientation) throws {
        var bg: UInt8 = 0
        let rotation: UInt8
        switch orientation {
        case .right, .rightMirrored:
            rotation = 3
        case .up, .downMirrored:
            rotation = 2
        case .left, .leftMirrored:
            rotation = 1
        case .down, .upMirrored:
            rotation = 0
        }
        let outWidth: UInt
        let outHeight: UInt
        // Flip width and height if the image is rotated 90 or 270 degrees
        if rotation == 1 || rotation == 3 {
            outWidth = UInt(self.height)
            outHeight = UInt(self.width)
        } else {
            outWidth = UInt(self.width)
            outHeight = UInt(self.height)
        }
        let bytesPerPixel: Int
        switch self.format {
        case .abgr, .argb, .bgra, .rgba:
            bytesPerPixel = 4
        case .rgb, .bgr:
            bytesPerPixel = 3
        case .grayscale:
            bytesPerPixel = 1
        }
        let length = self.height*self.bytesPerRow
        let ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
        var data = [UInt8](self.data)
        let dataPointer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
        dataPointer.initialize(from: &data, count: data.count)
        var src = vImage_Buffer(data: dataPointer, height: UInt(self.height), width: UInt(self.width), rowBytes: self.bytesPerRow)
        defer {
            src.free()
        }
        var dst = vImage_Buffer(data: ptr, height: outHeight, width: outWidth, rowBytes: Int(outWidth)*bytesPerPixel)
        defer {
            dst.free()
        }
        switch self.format {
        case .abgr, .argb, .bgra, .rgba:
            guard vImageRotate90_ARGB8888(&src, &dst, rotation, &bg, numericCast(kvImageNoFlags)) == kvImageNoError else {
                throw ImageError.imageRotationFailed
            }
        case .rgb, .bgr:
            let argbBytes = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(width) * 4 * Int(height))
            var argbBuffer = vImage_Buffer(data: argbBytes, height: UInt(self.height), width: UInt(self.width), rowBytes: self.width * 4)
            defer {
                argbBuffer.free()
            }
            guard vImageConvert_RGB888toARGB8888(&src, nil, 0xFF, &argbBuffer, false, numericCast(kvImageNoFlags)) == kvImageNoError else {
                throw ImageError.imageConversionFailed
            }
            let rotatedArgbBytes = UnsafeMutablePointer<UInt8>.allocate(capacity: self.width * 4 * self.height)
            var rotatedArgbBuffer = vImage_Buffer(data: rotatedArgbBytes, height: outHeight, width: outWidth, rowBytes: Int(outWidth) * 4)
            defer {
                rotatedArgbBuffer.free()
            }
            guard vImageRotate90_ARGB8888(&argbBuffer, &rotatedArgbBuffer, rotation, &bg, numericCast(kvImageNoFlags)) == kvImageNoError else {
                throw ImageError.imageRotationFailed
            }
            guard vImageConvert_ARGB8888toRGB888(&rotatedArgbBuffer, &dst, numericCast(kvImageNoFlags)) == kvImageNoError else {
                throw ImageError.imageConversionFailed
            }
        case .grayscale:
            guard vImageRotate90_Planar8(&src, &dst, rotation, bg, numericCast(kvImageNoFlags)) == kvImageNoError else {
                throw ImageError.imageRotationFailed
            }
        }
        self.data = Data(buffer: UnsafeBufferPointer(start: ptr, count: length))
        self.width = Int(outWidth)
        self.height = Int(outHeight)
        self.bytesPerRow = Int(outWidth) * bytesPerPixel
    }
    
    #if canImport(UIKit)
    /// Apply the given orientation to the image
    /// - Parameter orientation: Orientation
    /// - Throws: ``ImageError``
    /// - Since: 1.0.0
    public mutating func applyOrientation(_ orientation: UIImage.Orientation) throws {
        let cgOrientation: CGImagePropertyOrientation
        switch orientation {
        case .up:
            cgOrientation = .up
        case .right:
            cgOrientation = .right
        case .down:
            cgOrientation = .down
        case .left:
            cgOrientation = .left
        case .upMirrored:
            cgOrientation = .upMirrored
        case .rightMirrored:
            cgOrientation = .rightMirrored
        case .downMirrored:
            cgOrientation = .downMirrored
        case .leftMirrored:
            cgOrientation = .leftMirrored
        default:
            cgOrientation = .up
        }
        return try self.applyOrientation(cgOrientation)
    }
    #endif
    
    /// Crop the image to the given rectangle
    /// - Parameter rect: Rectangle to which the image will be cropped
    /// - Since: 1.0.0
    public mutating func cropToRect(_ rect: CGRect) {
        let x: Int = Int(rect.minX.rounded(.up))
        let cols: Int = Int(rect.maxX.rounded(.down)) - x
        let rowBytes: Int = cols * self.format.bytesPerPixel
        let y: Int = Int(rect.minY.rounded(.up))
        let rows: Int = Int(rect.maxY.rounded(.down)) - y
        var data = Data()
        for top in y..<y + rows {
            let startIndex = top * self.bytesPerRow + x * self.format.bytesPerPixel
            let endIndex = startIndex + rowBytes
            data.append(contentsOf: self.data[startIndex..<endIndex])
        }
        self.data = data
        self.bytesPerRow = rowBytes
        self.width = cols
        self.height = rows
    }
}
