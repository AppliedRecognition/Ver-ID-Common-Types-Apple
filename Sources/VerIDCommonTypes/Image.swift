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

public struct Image: Hashable, @unchecked Sendable {
    
    private static let ciContext = CIContext(options: [.cacheIntermediates: false])
    
    // Reusable CVPixelBuffer pools keyed by (width,height,pixelFormat) with LRU eviction
    private static var pixelBufferPools: [String: CVPixelBufferPool] = [:]
    private static var pixelBufferPoolsLRU: [String] = [] // most-recently-used at end
    private static let pixelBufferPoolsLock = NSLock()
    private static let pixelBufferPoolsCapacity = 32

    public static func clearPixelBufferPools() {
        pixelBufferPoolsLock.lock()
        pixelBufferPools.removeAll()
        pixelBufferPoolsLRU.removeAll()
        pixelBufferPoolsLock.unlock()
    }

    private static func poolKey(width: Int, height: Int, pixelFormat: OSType) -> String {
        "\(width)x\(height)-\(pixelFormat)"
    }

    private static func pixelBufferPool(width: Int, height: Int, pixelFormat: OSType = kCVPixelFormatType_32BGRA, minimumBufferCount: Int = 3) -> CVPixelBufferPool? {
        let key = poolKey(width: width, height: height, pixelFormat: pixelFormat)
        pixelBufferPoolsLock.lock()
        defer { pixelBufferPoolsLock.unlock() }

        // Hit: return existing and mark as most-recently-used
        if let existing = pixelBufferPools[key] {
            if let idx = pixelBufferPoolsLRU.firstIndex(of: key) {
                pixelBufferPoolsLRU.remove(at: idx)
            }
            pixelBufferPoolsLRU.append(key)
            return existing
        }

        // Miss: create a new pool
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(pixelFormat),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        let poolOpts: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: minimumBufferCount
        ]
        var pool: CVPixelBufferPool?
        let status = CVPixelBufferPoolCreate(kCFAllocatorDefault, poolOpts as CFDictionary, attrs as CFDictionary, &pool)
        guard status == kCVReturnSuccess, let pool else { return nil }

        // Insert and mark as MRU
        pixelBufferPools[key] = pool
        pixelBufferPoolsLRU.append(key)

        // Evict if over capacity (remove LRU at front)
        if pixelBufferPoolsLRU.count > pixelBufferPoolsCapacity, let lruKey = pixelBufferPoolsLRU.first {
            pixelBufferPoolsLRU.removeFirst()
            pixelBufferPools.removeValue(forKey: lruKey)
        }
        return pool
    }
    
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
        guard let videoAndDepth: (CVPixelBuffer, AVDepthData?) = autoreleasepool(invoking: {
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
            guard let buffer = Image.createCVPixelBuffer(from: cgImage, orientation: orientation) else {
                return nil
            }
            if let depthAuxDataInfo = CGImageSourceCopyAuxiliaryDataInfoAtIndex(imageSource, 0, kCGImageAuxiliaryDataTypeDepth as CFString) as? [AnyHashable: Any],
                  let depthData = try? AVDepthData(fromDictionaryRepresentation: depthAuxDataInfo) {
                if orientation != .up {
                    return (buffer, depthData.applyingExifOrientation(orientation))
                } else {
                    return (buffer, depthData)
                }
            } else {
                return (buffer, nil)
            }
        }) else {
            return nil
        }
        self.videoBuffer = videoAndDepth.0
        self.depthData = videoAndDepth.1
    }
    
    public init?(cgImage: CGImage, orientation: CGImagePropertyOrientation = .up, depthData: AVDepthData? = nil) {
        guard let videoBuffer: CVPixelBuffer = autoreleasepool(invoking: {
            Image.createCVPixelBuffer(from: cgImage, orientation: orientation)
        }) else {
            return nil
        }
        self.videoBuffer = videoBuffer
        self.depthData = depthData?.applyingExifOrientation(orientation)
    }
    
    #if canImport(UIKit)
    
    public init?(uiImage: UIImage, depthData: AVDepthData? = nil) {
        guard let videoBuffer: CVPixelBuffer = autoreleasepool(invoking: {
            if let cgImage = uiImage.cgImage {
                guard let buffer = Image.createCVPixelBuffer(from: cgImage, orientation: uiImage.imageOrientation.cgImagePropertyOrientation) else {
                    return nil
                }
                return buffer
            } else if let ciImage = uiImage.ciImage, let buffer = Image.createCVPixelBuffer(from: ciImage) {
                return buffer
            } else {
                return nil
            }
        }) else {
            return nil
        }
        self.videoBuffer = videoBuffer
        self.depthData = depthData?.applyingExifOrientation(uiImage.imageOrientation.cgImagePropertyOrientation)
    }
    
    public func toUIImage() -> UIImage? {
        if let cgImage = self.toCGImage() {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
    
    #endif
    
    // Method to persist the Image in HEIC format
    public func toHEIC() -> Data? {
        return autoreleasepool {
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
                if let depthDict = depthData.dictionaryRepresentation(forAuxiliaryDataType: &auxDataType), let auxDataType {
                    CGImageDestinationAddAuxiliaryDataInfo(destination, auxDataType, depthDict as CFDictionary)
                }
            }
            // Finalize the destination to write to data
            guard CGImageDestinationFinalize(destination) else {
                return nil
            }
            return data as Data
        }
    }
    
    public func toCGImage() -> CGImage? {
        return autoreleasepool {
            Image.createCGImage(from: self.videoBuffer)
        }
    }
    
    private func imageCoordinatesToDepthCoordinates(x: Int, y: Int) -> (Int, Int)? {
        guard let depthData = self.depthData, let cameraCalibrationData = depthData.cameraCalibrationData else {
            return nil
        }
        let referenceDimensions = cameraCalibrationData.intrinsicMatrixReferenceDimensions
        let rotatedX: CGFloat = CGFloat(x)
        let rotatedY: CGFloat = CGFloat(y)
        let imageWidth: CGFloat = CGFloat(self.width)
        let imageHeight: CGFloat = CGFloat(self.height)
        let normX = rotatedX / imageWidth * referenceDimensions.width
        let normY = rotatedY / imageHeight * referenceDimensions.height
        let depthMapWidth = CGFloat(CVPixelBufferGetWidth(depthData.depthDataMap))
        let depthMapHeight = CGFloat(CVPixelBufferGetHeight(depthData.depthDataMap))
        let depthX = Int(normX / referenceDimensions.width * depthMapWidth)
        let depthY = Int(normY / referenceDimensions.height * depthMapHeight)
        return (depthX, depthY)
    }
    
    public func coordinates3dAt(x: Int, y: Int) -> simd_float3? {
        guard let originalDepthData = self.depthData else {
            return nil
        }
        let depthData = originalDepthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
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
        let X_camera = (Float(depthX) - cx) * depth / fx
        let Y_camera = (Float(depthY) - cy) * depth / fy
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
        // Attempt to wrap the pixel buffer memory into a vImage buffer for efficient re-orientation
        if let wrapped = Image.vImageBuffer(from: pixelBuffer) {
            // Prepare destination dimensions depending on orientation
            let needsSwap = (orientation == .left || orientation == .right || orientation == .leftMirrored || orientation == .rightMirrored)
            let dstWidth = needsSwap ? wrapped.height : wrapped.width
            let dstHeight = needsSwap ? wrapped.width : wrapped.height
            guard let pool = Image.pixelBufferPool(width: Int(dstWidth), height: Int(dstHeight), pixelFormat: kCVPixelFormatType_32BGRA) else {
                // Fallback to CI-based orientation if pool fails
                return autoreleasepool {
                    let ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
                    return Image.createCVPixelBuffer(from: ciImage) ?? pixelBuffer
                }
            }
            var outPixelBufferOpt: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &outPixelBufferOpt) == kCVReturnSuccess, let outPixelBuffer = outPixelBufferOpt else {
                return autoreleasepool {
                    let ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
                    return Image.createCVPixelBuffer(from: ciImage) ?? pixelBuffer
                }
            }
            CVPixelBufferLockBaseAddress(outPixelBuffer, [])
            defer { CVPixelBufferUnlockBaseAddress(outPixelBuffer, []) }
            guard let outBase = CVPixelBufferGetBaseAddress(outPixelBuffer) else {
                return autoreleasepool {
                    let ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
                    return Image.createCVPixelBuffer(from: ciImage) ?? pixelBuffer
                }
            }
            var dest = vImage_Buffer(
                data: outBase,
                height: vImagePixelCount(dstHeight),
                width: vImagePixelCount(dstWidth),
                rowBytes: CVPixelBufferGetBytesPerRow(outPixelBuffer)
            )
            do {
                var src = wrapped // local mutable copy for API
                try Image.applyOrientation(orientation, src: &src, dest: &dest)
                return outPixelBuffer
            } catch {
                // Fallback to CI if vImage fails
                return autoreleasepool {
                    let ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
                    return Image.createCVPixelBuffer(from: ciImage) ?? pixelBuffer
                }
            }
        }
        // Fallback path uses Core Image orientation if wrapping not possible
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
        return autoreleasepool { Image.createCVPixelBuffer(from: ciImage) } ?? pixelBuffer
    }
    
    private static func createCGImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        return autoreleasepool {
            let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)

            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

            guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
                return nil
            }
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGBitmapInfo.byteOrder32Little.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue))

            // Fast path for BGRA buffers: wrap memory directly
            if format == kCVPixelFormatType_32BGRA {
                guard let provider = CGDataProvider(dataInfo: nil, data: baseAddress, size: bytesPerRow * height, releaseData: { _,_,_ in }) else {
                    return nil
                }
                return CGImage(
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bitsPerPixel: 32,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: bitmapInfo,
                    provider: provider,
                    decode: nil,
                    shouldInterpolate: false,
                    intent: .defaultIntent
                )
            }

            // Convert other supported formats to BGRA using vImage
            let dstBytesPerRow = width * 4
            let byteCount = dstBytesPerRow * height
            guard let dstData = malloc(byteCount) else { return nil }
            var dstBuffer = vImage_Buffer(data: dstData, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: dstBytesPerRow)

            var success = false

            switch format {
            case kCVPixelFormatType_32ARGB:
                // Wrap source as vImage buffer
                var srcBuffer = vImage_Buffer(data: baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: bytesPerRow)
                // Permute ARGB -> BGRA (indices for ARGB8888 are [A,R,G,B])
                var permute: [UInt8] = [3, 2, 1, 0] // B,G,R,A
                let err = vImagePermuteChannels_ARGB8888(&srcBuffer, &dstBuffer, &permute, vImage_Flags(kvImageNoFlags))
                success = (err == kvImageNoError)

            case kCVPixelFormatType_OneComponent8:
                // Grayscale 8-bit -> write ARGB (R=G=B=Y, A=255) directly into dstBuffer
                var planarY = vImage_Buffer(data: baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: bytesPerRow)

                // Allocate planar alpha and fill with 255
                let aRowBytes = width
                let aByteCount = aRowBytes * height
                guard let aData = malloc(aByteCount) else { free(dstData); return nil }
                defer { free(aData) }
                memset(aData, 255, aByteCount)
                var planarA = vImage_Buffer(data: aData, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: aRowBytes)

                // Convert Planar8 (Y) to ARGB8888 directly into dstBuffer (chunky)
                // Signature: vImageConvert_Planar8toARGB8888(R, G, B, A, destARGB, flags)
                let err = vImageConvert_Planar8toARGB8888(&planarY, &planarY, &planarY, &planarA, &dstBuffer, vImage_Flags(kvImageNoFlags))
                success = (err == kvImageNoError)

            default:
                success = false
            }

            guard success else { free(dstData); return nil }

            // Build CGImage from converted BGRA buffer
            guard let provider = CGDataProvider(dataInfo: nil, data: dstData, size: byteCount, releaseData: { _, data, _ in
                free(UnsafeMutableRawPointer(mutating: data))
            }) else {
                free(dstData)
                return nil
            }

            return CGImage(
                width: width,
                height: height,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: dstBytesPerRow,
                space: colorSpace,
                bitmapInfo: bitmapInfo,
                provider: provider,
                decode: nil,
                shouldInterpolate: false,
                intent: .defaultIntent
            )
        }
    }
    
    private static func createCVPixelBuffer(from ciImage: CIImage) -> CVPixelBuffer? {
        return autoreleasepool {
            let width = Int(ciImage.extent.width)
            let height = Int(ciImage.extent.height)
            
            guard let pool = Image.pixelBufferPool(width: width, height: height) else {
                return nil
            }
            var bufferOut: CVPixelBuffer?
            let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &bufferOut)
            guard status == kCVReturnSuccess, let buffer = bufferOut else {
                return nil
            }
            Image.ciContext.render(ciImage, to: buffer)
            return buffer
        }
    }
    
    // Wrap a CVPixelBuffer's base address as a vImage_Buffer (no allocation). Returns nil if unsupported format.
    private static func vImageBuffer(from pixelBuffer: CVPixelBuffer) -> vImage_Buffer? {
        let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
        // We only support 32BGRA here which maps to ARGB8888 in vImage with byteOrder32Little + premultipliedFirst
        guard format == kCVPixelFormatType_32BGRA else { return nil }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
        return vImage_Buffer(data: base, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: rowBytes)
    }

    // Create a new vImage_Buffer by copying from CVPixelBuffer into newly allocated memory (caller must free).
    // Useful if you need an owned buffer independent of the pixel buffer's lifetime.
    private static func vImageBufferCopy(from pixelBuffer: CVPixelBuffer) -> vImage_Buffer? {
        let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
        guard format == kCVPixelFormatType_32BGRA else { return nil }
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        let srcRowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
        let bytesPerPixel = 4
        let dstRowBytes = width * bytesPerPixel
        let byteCount = dstRowBytes * height
        guard let dstData = malloc(byteCount) else { return nil }
        var srcBuf = vImage_Buffer(data: base, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: srcRowBytes)
        var dstBuf = vImage_Buffer(data: dstData, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: dstRowBytes)
        let err = vImageCopyBuffer(&srcBuf, &dstBuf, bytesPerPixel, vImage_Flags(kvImageNoFlags))
        guard err == kvImageNoError else {
            free(dstData)
            return nil
        }
        return dstBuf
    }
    
    private static func applyOrientation(_ orientation: CGImagePropertyOrientation, src: inout vImage_Buffer, dest: inout vImage_Buffer) throws {
        var bgColor = 0
        /*
         kRotate0DegreesClockwise            = 0
         kRotate90DegreesClockwise           = 1
         kRotate180DegreesClockwise          = 2
         kRotate270DegreesClockwise          = 3
         */
        var error: vImage_Error?
        switch orientation {
        case .left:
            error = vImageRotate90_ARGB8888(&src, &dest, UInt8(kRotate270DegreesClockwise), &bgColor, vImage_Flags(kvImageNoFlags))
        case .right:
            error = vImageRotate90_ARGB8888(&src, &dest, UInt8(kRotate90DegreesClockwise), &bgColor, vImage_Flags(kvImageNoFlags))
        case .down:
            error = vImageRotate90_ARGB8888(&src, &dest, UInt8(kRotate180DegreesClockwise), &bgColor, vImage_Flags(kvImageNoFlags))
        case .upMirrored:
            error = vImageHorizontalReflect_ARGB8888(&src, &dest, vImage_Flags(kvImageNoFlags))
        case .downMirrored:
            // mirror then rotate 180
            error = vImageHorizontalReflect_ARGB8888(&src, &dest, vImage_Flags(kvImageNoFlags))
            if error == kvImageNoError {
                var rotated = vImage_Buffer()
                // reuse tmp buffer for rotated to save memory
                rotated = src
                error = vImageRotate90_ARGB8888(&dest, &rotated, UInt8(kRotate180DegreesClockwise), &bgColor, vImage_Flags(kvImageNoFlags))
                if error == kvImageNoError {
                    // copy back into intermediate
                    error = vImageCopyBuffer(&rotated, &dest, 4, vImage_Flags(kvImageNoFlags))
                }
            }
        case .leftMirrored:
            // rotate left then mirror horizontally
            error = vImageRotate90_ARGB8888(&src, &dest, UInt8(kRotate90DegreesClockwise), &bgColor, vImage_Flags(kvImageNoFlags))
            if error == kvImageNoError {
                error = vImageHorizontalReflect_ARGB8888(&dest, &dest, vImage_Flags(kvImageNoFlags))
            }
        case .rightMirrored:
            // rotate right then mirror horizontally
            error = vImageRotate90_ARGB8888(&src, &dest, UInt8(kRotate270DegreesClockwise), &bgColor, vImage_Flags(kvImageNoFlags))
            if error == kvImageNoError {
                error = vImageHorizontalReflect_ARGB8888(&dest, &dest, vImage_Flags(kvImageNoFlags))
            }
        default:
            error = kvImageNoError
        }
        guard error == kvImageNoError else {
            throw ImageError.imageRotationFailed
        }
    }

    private static func createCVPixelBuffer(from cgImage: CGImage, orientation: CGImagePropertyOrientation) -> CVPixelBuffer? {
        return autoreleasepool {
            // Determine destination size based on orientation
            let srcWidth = cgImage.width
            let srcHeight = cgImage.height
            let needsSwap = (orientation == .left || orientation == .right || orientation == .leftMirrored || orientation == .rightMirrored)
            let dstWidth = needsSwap ? srcHeight : srcWidth
            let dstHeight = needsSwap ? srcWidth : srcHeight
            
            guard let pool = pixelBufferPool(width: dstWidth, height: dstHeight, pixelFormat: kCVPixelFormatType_32BGRA) else {
                return nil
            }
            var pixelBufferOpt: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBufferOpt) == kCVReturnSuccess, let pixelBuffer = pixelBufferOpt else {
                return nil
            }
            
            CVPixelBufferLockBaseAddress(pixelBuffer, [])
            defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
            
            guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
            
            let dstRowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer)
            
            // vImage formats
            guard var destFormat = vImage_CGImageFormat(bitsPerComponent: 8,
                                                        bitsPerPixel: 32,
                                                        colorSpace: cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
                                                        bitmapInfo: CGBitmapInfo.byteOrder32Little.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)),
                                                        renderingIntent: .defaultIntent) else {
                return nil
            }
            guard var srcFormat = vImage_CGImageFormat(bitsPerComponent: cgImage.bitsPerComponent,
                                                       bitsPerPixel: cgImage.bitsPerPixel,
                                                       colorSpace: cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
                                                       bitmapInfo: cgImage.bitmapInfo,
                                                       renderingIntent: cgImage.renderingIntent) else {
                return nil
            }
            
            // Create source buffer from CGImage
            var srcBuffer = vImage_Buffer()
            var error = vImageBuffer_InitWithCGImage(&srcBuffer, &srcFormat, nil, cgImage, vImage_Flags(kvImageNoFlags))
            guard error == kvImageNoError else {
                return nil
            }
            defer { free(srcBuffer.data) }
            
            // Destination buffer wrapping pixel buffer memory
            var dstBuffer = vImage_Buffer(data: baseAddress, height: vImagePixelCount(dstHeight), width: vImagePixelCount(dstWidth), rowBytes: dstRowBytes)
            
            // Build a converter from source to BGRA8 using managed API
            guard let converter = vImageConverter_CreateWithCGImageFormat(&srcFormat, &destFormat, nil, vImage_Flags(kvImageNoFlags), &error)?.takeRetainedValue() else {
                return nil
            }
            
            // If orientation is up, convert directly into destination
            if orientation == .up {
                error = vImageConvert_AnyToAny(converter, &srcBuffer, &dstBuffer, nil, vImage_Flags(kvImageNoFlags))
                guard error == kvImageNoError else { return nil }
                return pixelBuffer
            }
            
            // Otherwise, convert to an intermediate BGRA buffer first
            let intermediateRowBytes = dstWidth * 4
            guard let intermediateData = malloc(dstHeight * intermediateRowBytes) else { return nil }
            defer { free(intermediateData) }
            var intermediate = vImage_Buffer(data: intermediateData, height: vImagePixelCount(dstHeight), width: vImagePixelCount(dstWidth), rowBytes: intermediateRowBytes)
            
            // Convert source into a temporary buffer sized like the source first (BGRA)
            let tmpRowBytes = srcWidth * 4
            guard let tmpData = malloc(srcHeight * tmpRowBytes) else { return nil }
            defer { free(tmpData) }
            var tmpBGRA = vImage_Buffer(data: tmpData, height: vImagePixelCount(srcHeight), width: vImagePixelCount(srcWidth), rowBytes: tmpRowBytes)
            
            // Create a destFormat identical (BGRA8) for tmp/intermediate
            guard var bgraFormat = vImage_CGImageFormat(bitsPerComponent: 8,
                                                        bitsPerPixel: 32,
                                                        colorSpace: cgImage.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
                                                        bitmapInfo: CGBitmapInfo.byteOrder32Little.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue)),
                                                        renderingIntent: .defaultIntent) else {
                return nil
            }
            guard let toBGRAConverter = vImageConverter_CreateWithCGImageFormat(&srcFormat, &bgraFormat, nil, vImage_Flags(kvImageNoFlags), nil)?.takeRetainedValue() else {
                return nil
            }
            
            error = vImageConvert_AnyToAny(toBGRAConverter, &srcBuffer, &tmpBGRA, nil, vImage_Flags(kvImageNoFlags))
            guard error == kvImageNoError else { return nil }
            
            do {
                try applyOrientation(orientation, src: &tmpBGRA, dest: &intermediate)
            } catch {
                return nil
            }
            
            // Copy oriented intermediate into destination pixel buffer (may differ in rowBytes)
            error = vImageCopyBuffer(&intermediate, &dstBuffer, 4, vImage_Flags(kvImageNoFlags))
            guard error == kvImageNoError else { return nil }
            
            return pixelBuffer
        }
    }
}

#if canImport(UIKit)

public extension UIImage {
    func toVerIDImage() throws -> Image {
        if let image = Image(uiImage: self) {
            return image
        } else {
            throw ImageError.imageConversionFailed
        }
    }
}

#endif

public extension CGImage {
    func toVerIDImage() throws -> Image {
        if let image = Image(cgImage: self) {
            return image
        } else {
            throw ImageError.imageConversionFailed
        }
    }
}

