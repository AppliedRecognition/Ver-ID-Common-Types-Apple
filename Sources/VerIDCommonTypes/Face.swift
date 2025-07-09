//
//  Face.swift
//
//
//  Created by Jakub Dolejs on 23/10/2023.
//

import Foundation
import CoreGraphics

/// Face
/// - Since: 1.0.0
public struct Face: Hashable, Sendable {
    
    /// Face bounds within the image (in pixels)
    /// - Since: 1.0.0
    public let bounds: CGRect
    /// Angle of the face
    /// - Since: 1.0.0
    public let angle: EulerAngle<Float>
    /// Face quality
    ///
    /// Ranges between `0.0` (worst quality) and `10.0` (best quality)
    /// - Since: 1.0.0
    public let quality: Float
    /// Face landmarks
    /// - Since: 1.0.0
    public let landmarks: [CGPoint]
    
    public let leftEye: CGPoint
    public let rightEye: CGPoint
    public let noseTip: CGPoint?
    public let mouthCentre: CGPoint?
    /// Coordinate of the left corner of the mouth
    /// - Since: 2.1.0
    public let mouthLeftCorner: CGPoint?
    /// Coordinate of the right corner of the mouth
    /// - Since: 2.1.0
    public let mouthRightCorner: CGPoint?
    
    /// Constructor
    /// - Parameters:
    ///   - bounds: Face bounds within the image (in pixels)
    ///   - angle: Angle of the face
    ///   - quality: Face quality
    ///   - landmarks: Face landmarks
    /// - Since: 1.0.0
    public init(bounds: CGRect, angle: EulerAngle<Float>, quality: Float, landmarks: [CGPoint], leftEye: CGPoint, rightEye: CGPoint, noseTip: CGPoint?=nil, mouthCentre: CGPoint?=nil, mouthLeftCorner: CGPoint?=nil, mouthRightCorner: CGPoint?=nil) {
        self.bounds = bounds
        self.angle = angle
        self.quality = quality
        self.landmarks = landmarks
        self.leftEye = leftEye
        self.rightEye = rightEye
        self.noseTip = noseTip
        self.mouthCentre = mouthCentre
        self.mouthLeftCorner = mouthLeftCorner
        self.mouthRightCorner = mouthRightCorner
    }
    
    /// Change the aspect ratio of the face
    ///
    /// The conversion will extend the shorter side of the face bounds to match the given aspect ratio
    /// - Parameter aspectRatio: Desired aspect ratio of the face
    /// - Returns: Face with its bounds changed to the given aspect ratio
    /// - Since: 1.0.0
    public func withBoundsSetToAspectRatio(_ aspectRatio: CGFloat) -> Face {
        var faceBounds = self.bounds
        let faceAspectRatio = faceBounds.width / faceBounds.height
        if faceAspectRatio > aspectRatio {
            let newHeight = faceBounds.width / aspectRatio
            faceBounds.origin.y = faceBounds.midY - newHeight / 2
            faceBounds.size.height = newHeight
        } else {
            let newWidth = faceBounds.height * aspectRatio
            faceBounds.origin.x = faceBounds.midX - newWidth / 2
            faceBounds.size.width = newWidth
        }
        return Face(bounds: faceBounds, angle: self.angle, quality: self.quality, landmarks: self.landmarks, leftEye: self.leftEye, rightEye: self.rightEye, noseTip: self.noseTip, mouthCentre: self.mouthCentre, mouthLeftCorner: self.mouthLeftCorner, mouthRightCorner: self.mouthRightCorner)
    }
    
    /// Apply an affine transform to the face bounds and landmarks
    /// - Parameter transform: Transform to apply to the face bounds and landmarks
    /// - Returns: Face that has the given transform applied to its bounds and landmarks
    /// - Since: 1.0.0
    public func applying(_ transform: CGAffineTransform) -> Face {
        let faceBounds = self.bounds.applying(transform)
        let landmarks = self.landmarks.map { $0.applying(transform) }
        let leftEye = self.leftEye.applying(transform)
        let rightEye = self.rightEye.applying(transform)
        let noseTip = self.noseTip?.applying(transform)
        let mouthCentre = self.mouthCentre?.applying(transform)
        let mouthLeftCorner = self.mouthLeftCorner?.applying(transform)
        let mouthRightCorner = self.mouthRightCorner?.applying(transform)
        return Face(bounds: faceBounds, angle: self.angle, quality: self.quality, landmarks: landmarks, leftEye: leftEye, rightEye: rightEye, noseTip: noseTip, mouthCentre: mouthCentre, mouthLeftCorner: mouthLeftCorner, mouthRightCorner: mouthRightCorner)
    }
}

extension Face: Comparable {
    
    public static func < (lhs: Self, rhs: Self) -> Bool {
        return lhs.bounds.width * lhs.bounds.height * CGFloat(lhs.quality) > rhs.bounds.width * rhs.bounds.height * CGFloat(rhs.quality)
    }
}
    
extension Face: Equatable {
    
    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.bounds == rhs.bounds && lhs.angle == rhs.angle && lhs.quality == rhs.quality && lhs.landmarks == rhs.landmarks
    }
}


fileprivate enum FaceCodingKeys: String, CodingKey {
    case bounds, angle, quality, landmarks, leftEye, rightEye, noseTip, mouthCentre, mouthLeftCorner, mouthRightCorner
}

fileprivate enum FaceBoundsCodingKeys: String, CodingKey {
    case x, y, width, height
}

extension Face: Codable {
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: FaceCodingKeys.self)
        let bounds = try container.nestedContainer(keyedBy: FaceBoundsCodingKeys.self, forKey: .bounds)
        let x = try bounds.decode(CGFloat.self, forKey: .x)
        let y = try bounds.decode(CGFloat.self, forKey: .y)
        let width = try bounds.decode(CGFloat.self, forKey: .width)
        let height = try bounds.decode(CGFloat.self, forKey: .height)
        self.angle = try container.decode(EulerAngle<Float>.self, forKey: .angle)
        self.quality = try container.decode(Float.self, forKey: .quality)
        let landmarks = try container.decode([CGFloat].self, forKey: .landmarks)
        self.bounds = CGRect(x: x, y: y, width: width, height: height)
        self.landmarks = stride(from: 0, to: landmarks.count, by: 2).map { index in
            CGPoint(x: landmarks[index], y: landmarks[index+1])
        }
        self.leftEye = try Face.decodePointFromArray(container: container, key: .leftEye)
        self.rightEye = try Face.decodePointFromArray(container: container, key: .rightEye)
        self.noseTip = try Face.decodeOptionalPointFromArray(container: container, key: .noseTip)
        self.mouthCentre = try Face.decodeOptionalPointFromArray(container: container, key: .mouthCentre)
        self.mouthLeftCorner = try Face.decodeOptionalPointFromArray(container: container, key: .mouthLeftCorner)
        self.mouthRightCorner = try Face.decodeOptionalPointFromArray(container: container, key: .mouthRightCorner)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: FaceCodingKeys.self)
        var bounds = container.nestedContainer(keyedBy: FaceBoundsCodingKeys.self, forKey: .bounds)
        try bounds.encode(self.bounds.minX, forKey: .x)
        try bounds.encode(self.bounds.minY, forKey: .y)
        try bounds.encode(self.bounds.width, forKey: .width)
        try bounds.encode(self.bounds.height, forKey: .height)
        try container.encode(self.angle, forKey: .angle)
        try container.encode(self.quality, forKey: .quality)
        let landmarks = self.landmarks.flatMap { [$0.x, $0.y] }
        try container.encode(landmarks, forKey: .landmarks)
        try container.encode([self.leftEye.x, self.leftEye.y], forKey: .leftEye)
        try container.encode([self.rightEye.x, self.rightEye.y], forKey: .rightEye)
        if let noseTip = self.noseTip {
            try container.encode([noseTip.x, noseTip.y], forKey: .noseTip)
        }
        if let mouthCentre = self.mouthCentre {
            try container.encode([mouthCentre.x, mouthCentre.y], forKey: .mouthCentre)
        }
        if let mouthLeftCorner = self.mouthLeftCorner {
            try container.encode([mouthLeftCorner.x, mouthLeftCorner.y], forKey: .mouthLeftCorner)
        }
        if let mouthRightCorner = self.mouthRightCorner {
            try container.encode([mouthRightCorner.x, mouthRightCorner.y], forKey: .mouthRightCorner)
        }
    }
    
    private static func decodePointFromArray(container: KeyedDecodingContainer<FaceCodingKeys>, key: FaceCodingKeys) throws -> CGPoint {
        let arr = try container.decode([CGFloat].self, forKey: key)
        return CGPoint(x: arr[0], y: arr[1])
    }
    
    private static func decodeOptionalPointFromArray(container: KeyedDecodingContainer<FaceCodingKeys>, key: FaceCodingKeys) throws -> CGPoint? {
        if let arr = try container.decodeIfPresent([CGFloat].self, forKey: key) {
            return CGPoint(x: arr[0], y: arr[1])
        }
        return nil
    }
}
