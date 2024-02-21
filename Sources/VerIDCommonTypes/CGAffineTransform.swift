//
//  File.swift
//  
//
//  Created by Jakub Dolejs on 02/02/2024.
//

import Foundation

public extension CGAffineTransform {
    
    /// Create an affine transform that transforms the source rectangle to the destination rectangle
    /// - Parameters:
    ///   - src: Source rectangle
    ///   - dst: Destination rectangle
    /// - Returns: Affine transform
    /// - Since: 1.0.0
    static func rect(_ src: CGRect, to dst: CGRect) -> CGAffineTransform {
        let scaleX = dst.width / src.width
        let scaleY = dst.height / src.height
        let translateX = dst.minX - src.minX * scaleX
        let translateY = dst.minY - src.minY * scaleY
        return CGAffineTransform(a: scaleX, b: 0, c: 0, d: scaleY, tx: translateX, ty: translateY)
    }
    
    /// Create an affine transform that mirrors the contents horizontally
    /// - Parameter width: Width of the content
    /// - Returns: Affine transform
    /// - Since: 1.0.0
    static func horizontalMirror(in width: CGFloat) -> CGAffineTransform {
        CGAffineTransform(scaleX: -1, y: 1).concatenating(CGAffineTransform(translationX: width, y: 0))
    }
}
