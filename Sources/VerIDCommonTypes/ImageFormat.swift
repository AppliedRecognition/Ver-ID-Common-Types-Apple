//
//  File.swift
//  
//
//  Created by Jakub Dolejs on 25/10/2023.
//

import Foundation

/// Image format
/// - Since: 1.0.0
public enum ImageFormat: Sendable, Codable {
    /// RGB – red, gree, blue
    case rgb
    /// BRG – blue, green, red
    case bgr
    /// ARGB – alpha, red, green, blue
    case argb
    /// BGRA – blue, green, red, alpha
    case bgra
    /// ABGR – alpha, blue, green, red
    case abgr
    /// RGBA – red, green, blue, alpha
    case rgba
    /// Grayscale
    case grayscale
    
    /// Number of bits per pixel in this format
    /// - Since: 1.0.0
    public var bitsPerPixel: Int {
        switch self {
        case .abgr, .argb, .bgra, .rgba:
            return 32
        case .rgb, .bgr:
            return 24
        default:
            return 8
        }
    }
    
    /// Number of bytes per pixel in this format
    /// - Since: 1.0.0
    public var bytesPerPixel: Int {
        switch self {
        case .abgr, .argb, .bgra, .rgba:
            return 4
        case .rgb, .bgr:
            return 3
        default:
            return 1
        }
    }
}
