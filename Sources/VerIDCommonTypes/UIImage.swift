//
//  File.swift
//  
//
//  Created by Jakub Dolejs on 25/10/2023.
//
#if canImport(UIKit)
import Foundation
import UIKit

/// Adds ``ImageConvertible`` protocol conformance to ``UIKit/UIImage`` 
extension UIImage: ImageConvertible {
    
    /// Convert the image to ``Image``
    /// - Returns: Image converted to ``Image``
    /// - Since: 1.0.0
    public func convertToImage() throws -> Image {
        return try self.convertToCGImage().convertToImage()
    }
    
    /// Convert the image to ``CoreGraphics/CGImage``
    /// - Returns: Image converted to ``CoreGraphics/CGImage``
    /// - Since: 1.0.0
    public func convertToCGImage() throws -> CGImage {
        UIGraphicsBeginImageContext(self.size)
        defer {
            UIGraphicsEndImageContext()
        }
        self.draw(at: .zero)
        if let img = UIGraphicsGetImageFromCurrentImageContext()?.cgImage {
            return img
        }
        throw ImageError.imageConversionFailed
    }
    
}
#endif
