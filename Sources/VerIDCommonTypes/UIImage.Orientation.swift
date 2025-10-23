//
//  UIImage.Orientation.swift
//  VerIDCommonTypes
//
//  Created by Jakub Dolejs on 23/10/2025.
//

#if canImport(UIKit)

import UIKit

extension UIImage.Orientation {
    var cgImagePropertyOrientation: CGImagePropertyOrientation {
        switch self {
        case .right:
            return .right
        case .down:
            return .down
        case .left:
            return .left
        case .upMirrored:
            return .upMirrored
        case .rightMirrored:
            return .rightMirrored
        case .downMirrored:
            return .downMirrored
        case .leftMirrored:
            return .leftMirrored
        default:
            return .up
        }
    }
}

#endif
