//
//  File.swift
//  
//
//  Created by Jakub Dolejs on 20/02/2024.
//

import Foundation
import CoreGraphics

public extension CGRect {
    
    /// Aspect ratio of the rectangle
    /// - Since: 1.0.0
    var aspectRatio: CGFloat {
        self.width / self.height
    }
}


extension CGRect: @retroactive Hashable {
    
    /// Hashable implementation
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.origin)
        hasher.combine(self.size)
    }
}
