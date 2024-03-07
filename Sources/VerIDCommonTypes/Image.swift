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
/// Image type used by Ver-ID libraries
/// - Since: 1.0.0
public struct Image: ImageConvertible, Hashable, Sendable, Codable {
    
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
    public func convertToImage() throws -> Image {
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
