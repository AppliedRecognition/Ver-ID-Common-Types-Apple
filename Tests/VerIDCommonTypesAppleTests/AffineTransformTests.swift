//
//  AffineTransformTests.swift
//
//
//  Created by Jakub Dolejs on 21/02/2024.
//

import XCTest
@testable import VerIDCommonTypes

final class AffineTransformTests: XCTestCase {
    
    func testRectToRectTransform() {
        let srcRect = CGRect(x: 10, y: 20, width: 100, height: 150)
        let destRect = CGRect(x: 30, y: 50, width: 200, height: 500)
        let transform = CGAffineTransform.rect(srcRect, to: destRect)
        let points: [CGPoint] = [
            CGPoint(x: 10, y: 20),
            CGPoint(x: 110, y: 20),
            CGPoint(x: 110, y: 170),
            CGPoint(x: 10, y: 170)
        ]
        let expectedPoints: [CGPoint] = [
            CGPoint(x: 30, y: 50),
            CGPoint(x: 230, y: 50),
            CGPoint(x: 230, y: 550),
            CGPoint(x: 30, y: 550)
        ]
        let transformedPoints = points.map { $0.applying(transform) }
        zip(transformedPoints, expectedPoints).forEach {
            XCTAssertEqual($0.0.x, $0.1.x, accuracy: 0.01)
            XCTAssertEqual($0.0.y, $0.1.y, accuracy: 0.01)
        }
    }
    
    func testMirrorTransform() {
        let width: CGFloat = 500
        let transform = CGAffineTransform.horizontalMirror(in: width)
        let point = CGPoint(x: 20, y: 0)
        let transformedPoint = point.applying(transform)
        XCTAssertEqual(transformedPoint.x, width - point.x, accuracy: 0.01)
    }
}
