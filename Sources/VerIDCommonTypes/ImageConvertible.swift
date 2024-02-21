//
//  File.swift
//  
//
//  Created by Jakub Dolejs on 25/10/2023.
//

import Foundation
import CoreGraphics

/// Protocol with methods to convert an image to ``Image`` and ``CoreGraphics/CGImage``
/// - Since: 1.0.0
public protocol ImageConvertible {
    
    /// Convert to ``Image``
    /// - Returns: Image converted to ``Image``
    /// - Since: 1.0.0
    func convertToImage() throws -> Image
    
    /// Convert to ``CoreGraphics/CGImage``
    /// - Returns: Image converted to ``CoreGraphics/CGImage``
    /// - Since: 1.0.0
    func convertToCGImage() throws -> CGImage
}
