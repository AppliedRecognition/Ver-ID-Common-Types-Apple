//
//  TaggedImage.swift
//
//
//  Created by Jakub Dolejs on 21/02/2024.
//

import Foundation

/// Image tagged with faces
/// - Since: 1.0.0
public struct TaggedImage: Hashable, Sendable {
    
    /// Image in which the ``faces`` were detected
    /// - Since: 1.0.0
    public let image: Image
    /// Faces detected in the ``image``
    /// - Since: 1.0.0
    public let faces: [Face]
}
