//
//  CGSize.swift
//  
//
//  Created by Jakub Dolejs on 21/02/2024.
//

import Foundation
import CoreGraphics

extension CGSize: Hashable {
    
    /// Hashable implementation
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.width)
        hasher.combine(self.height)
    }
}
