//
//  Version.swift
//
//
//  Created by Jakub Dolejs on 12/02/2024.
//

import Foundation

/// Version that follows semantic versioning
/// - Since: 1.0.0
public struct Version: Hashable, Comparable {
    
    /// Major version
    ///
    /// Change in the major version represents breaking API changes
    /// - Since: 1.0.0
    public let major: Int
    /// Minor version
    ///
    /// Change in the minor version represents backward-compatible API changes
    /// - Since: 1.0.0
    public let minor: Int
    /// Patch version
    ///
    /// Changes in the patch version represent changes that don't affect the API
    /// - Since: 1.0.0
    public let patch: Int
    
    var number: Int {
        self.major * 1_000_000 + self.minor * 1_000 + self.patch
    }
    
    /// Constructor
    /// - Parameters:
    ///   - major: Major version
    ///   - minor: Minor version
    ///   - patch: Patch version
    /// - Since: 1.0.0
    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }
    
    /// Version string
    /// - Since: 1.0.0
    public var string: String {
        "\(self.major).\(self.minor).\(self.patch)"
    }
    
    
    /// Check whether this version is compatible with the given version
    /// - Parameter version: Version
    /// - Returns: `true` if this version can consume and API with the given version
    /// - Since: 1.0.0
    public func isCompatible(with version: Version) -> Bool {
        self.major == version.major && self.minor <= version.minor
    }
    
    /// Comparable implementation
    public static func < (lhs: Version, rhs: Version) -> Bool {
        lhs.number < rhs.number
    }
}
