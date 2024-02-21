//
//  File.swift
//  
//
//  Created by Jakub Dolejs on 30/01/2024.
//

import Foundation
import UIKit
import ImageIO
import AVFoundation

extension UIDeviceOrientation {
    
    /// Device orientation converted to `CGImagePropertyOrientation`
    /// - Since: 1.0.0
    var cgImagePropertyOrientation: CGImagePropertyOrientation {
        switch self {
        case .landscapeLeft:
            return .up
        case .landscapeRight:
            return .down
        case .portraitUpsideDown:
            return .left
        default:
            return .right
        }
    }
    
    /// Device orientation converted to `AVCaptureVideoOrientation`
    /// - Since: 1.0.0
    var videoOrientation: AVCaptureVideoOrientation {
        switch self {
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        case .portraitUpsideDown:
            return .portraitUpsideDown
        default:
            return .portrait
        }
    }
}
