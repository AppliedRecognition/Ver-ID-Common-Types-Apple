//
//  File.swift
//  
//
//  Created by Jakub Dolejs on 23/10/2023.
//

import Foundation

/// Euler angle
/// - Since: 1.0.0
public struct EulerAngle<T>: Hashable, Sendable where T: Numeric, T: Hashable, T: Sendable {
    
    /// Yaw
    /// - Since: 1.0.0
    public var yaw: T
    /// Pitch
    /// - Since: 1.0.0
    public var pitch: T
    /// Roll
    /// - Since: 1.0.0
    public var roll: T
    
    /// Constructor
    ///
    /// Sets all values to `0`
    /// - Since: 1.0.0
    public init() {
        self.yaw = 0
        self.pitch = 0
        self.roll = 0
    }
    
    /// Constructor
    /// - Parameters:
    ///   - yaw: Yaw
    ///   - pitch: Pitch
    ///   - roll: Roll
    /// - Since: 1.0.0
    public init(yaw: T, pitch: T, roll: T) {
        self.yaw = yaw
        self.pitch = pitch
        self.roll = roll
    }
    
    /// Identity angle
    ///
    /// The yaw, pitch and roll are set to `0`
    /// - Since: 1.0.0
    public static var identity: EulerAngle<T> {
        .init()
    }
    
    /// Equatable implementation
    public static func == (lhs: EulerAngle<T>, rhs: EulerAngle<T>) -> Bool {
        lhs.yaw == rhs.yaw && lhs.pitch == rhs.pitch && lhs.roll == rhs.roll
    }
}
