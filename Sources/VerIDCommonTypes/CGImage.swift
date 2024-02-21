//
//  File 2.swift
//  
//
//  Created by Jakub Dolejs on 25/10/2023.
//

import Foundation
import CoreGraphics
import Accelerate

/// Adds ``ImageConvertible`` protocol conformance to ``CoreGraphics/CGImage``
extension CGImage: ImageConvertible {
    
    /// ImageConvertible implementation
    /// - Returns: Itself
    /// - Since: 1.0.0
    public func convertToCGImage() throws -> CGImage {
        self
    }
    
    /// ImageConvertible implementation
    /// - Returns: Image converted to ``Image``
    /// - Since: 1.0.0
    public func convertToImage() throws -> Image {
        var colourSpace: Unmanaged<CGColorSpace>
        if self.colorSpace != nil {
            colourSpace = Unmanaged.passRetained(self.colorSpace!)
        } else {
            colourSpace = Unmanaged.passRetained(CGColorSpaceCreateDeviceRGB())
        }
        defer {
            colourSpace.release()
        }
        var format = vImage_CGImageFormat(bitsPerComponent: UInt32(self.bitsPerComponent), bitsPerPixel: UInt32(self.bitsPerPixel), colorSpace: colourSpace, bitmapInfo: self.bitmapInfo, version: 0, decode: nil, renderingIntent: .defaultIntent)
        let originalBufferLength = self.height * self.bytesPerRow
        let originalBytes = UnsafeMutablePointer<UInt8>.allocate(capacity: originalBufferLength)
        let width = UInt(self.width)
        let height = UInt(self.height)
        let rowBytes = self.bytesPerRow
        var src = vImage_Buffer(data: originalBytes, height: height, width: width, rowBytes: rowBytes)
        defer {
            src.free()
        }
        guard vImageBuffer_InitWithCGImage(&src, &format, nil, self, numericCast(kvImageNoAllocate)) == kvImageNoError else {
            throw ImageError.imageConversionFailed
        }
        return Image(data: Data(buffer: UnsafeBufferPointer(start: originalBytes, count: originalBufferLength)), width: self.width, height: self.height, bytesPerRow: bytesPerRow, format: format.bitmapInfo.imageFormat)
    }
}

extension CGBitmapInfo {
    var imageFormat: ImageFormat {
        
        // AlphaFirst – the alpha channel is next to the red channel, argb and bgra are both alpha first formats.
        // AlphaLast – the alpha channel is next to the blue channel, rgba and abgr are both alpha last formats.
        // LittleEndian – blue comes before red, bgra and abgr are little endian formats.
        // Little endian ordered pixels are BGR (BGRX, XBGR, BGRA, ABGR, BGR).
        // BigEndian – red comes before blue, argb and rgba are big endian formats.
        // Big endian ordered pixels are RGB (XRGB, RGBX, ARGB, RGBA, RGB).
        
        let alphaInfo: CGImageAlphaInfo? = CGImageAlphaInfo(rawValue: self.rawValue & type(of: self).alphaInfoMask.rawValue)
        let alphaFirst: Bool = alphaInfo == .premultipliedFirst || alphaInfo == .first || alphaInfo == .noneSkipFirst
        let alphaLast: Bool = alphaInfo == .premultipliedLast || alphaInfo == .last || alphaInfo == .noneSkipLast
        let endianLittle: Bool = self.contains(.byteOrder32Little)
        
        // This is slippery… while byte order host returns little endian, default bytes are stored in big endian
        // format. Here we just assume if no byte order is given, then simple RGB is used, aka big endian, though…
        
        if alphaFirst && endianLittle {
            return .bgra
        } else if alphaFirst {
            return .argb
        } else if alphaLast && endianLittle {
            return .abgr
        } else if alphaLast {
            return .rgba
        } else if endianLittle {
            return .bgr
        } else {
            return .rgb
        }
    }
}
