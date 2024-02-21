//
//  File.swift
//  
//
//  Created by Jakub Dolejs on 31/10/2023.
//

import UIKit
import ImageIO

public extension UIInterfaceOrientation {
    
    /// Orientation converted to `CGImagePropertyOrientation`
    /// - Since: 1.0.0
    var cgImageOrientation: CGImagePropertyOrientation {
        switch (self) {
        case .portraitUpsideDown:
            return .left
        case .landscapeLeft:
            return .up
        case .landscapeRight:
            return .down
        default:
            return .right
        }
    }
}
