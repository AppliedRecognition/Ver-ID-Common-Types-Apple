//
//  CGPoint.swift
//  
//
//  Created by Jakub Dolejs on 21/02/2024.
//

import Foundation
import CoreGraphics

extension CGPoint: Hashable {
    
    /// Hashable implementation
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.x)
        hasher.combine(self.y)
    }
}
