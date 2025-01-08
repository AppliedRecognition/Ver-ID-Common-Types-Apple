//
//  CodableTests.swift
//  
//
//  Created by Jakub Dolejs on 23/02/2024.
//

import XCTest
import JSONSchema
@testable import VerIDCommonTypes

final class CodableTests: XCTestCase {

    func testEncodeFace() throws {
        let encoded = try JSONEncoder().encode(self.testFace)
        let schema: [String:Any] = try self.faceSchema
        let fromEncoded = try JSONSerialization.jsonObject(with: encoded)
        let validation = try JSONSchema.validate(fromEncoded, schema: schema)
        XCTAssertTrue(validation.valid)
    }

    func testDecodeFace() throws {
        let face = self.testFace
        let jsonFace: [String:Any] = [
            "bounds": [
                "x": face.bounds.minX,
                "y": face.bounds.minY,
                "width": face.bounds.width,
                "height": face.bounds.height
            ],
            "angle": [
                "yaw": face.angle.yaw,
                "pitch": face.angle.pitch,
                "roll": face.angle.roll
            ],
            "quality": face.quality,
            "landmarks": face.landmarks.flatMap({ [$0.x, $0.y]}),
            "leftEye": [face.leftEye.x, face.leftEye.y],
            "rightEye": [face.rightEye.x, face.rightEye.y],
            "noseTip": [face.noseTip!.x, face.noseTip!.y],
            "mouthCentre": [face.mouthCentre!.x, face.mouthCentre!.y]
        ]
        let schema = try self.faceSchema
        XCTAssertTrue(try JSONSchema.validate(jsonFace, schema: schema).valid)
        let encodedFace = try JSONSerialization.data(withJSONObject: jsonFace)
        let decodedFace = try JSONDecoder().decode(Face.self, from: encodedFace)
        XCTAssertEqual(decodedFace, face)
    }
    
    func testDecodeImage() throws {
        guard let url = Bundle.module.url(forResource: "Image", withExtension: "heic") else {
            throw TestError.genericError
        }
        let data = try Data(contentsOf: url)
        let image = Image(heicData: data)
        XCTAssertNotNil(image)
        XCTAssertNotNil(image!.depthData)
        XCTAssertEqual(CVPixelBufferGetWidth(image!.videoBuffer), 1080)
        XCTAssertEqual(CVPixelBufferGetHeight(image!.videoBuffer), 1920)
        XCTAssertEqual(CVPixelBufferGetWidth(image!.depthData!.depthDataMap), 360)
        XCTAssertEqual(CVPixelBufferGetHeight(image!.depthData!.depthDataMap), 640)
    }
    
    func testEncodeImage() throws {
        guard let url = Bundle.module.url(forResource: "Image", withExtension: "heic") else {
            throw TestError.genericError
        }
        let data = try Data(contentsOf: url)
        let image = Image(heicData: data)
        XCTAssertNotNil(image)
        let heic = image?.toHEIC()
        XCTAssertNotNil(heic)
    }
    
    private var faceSchema: [String:Any] {
        get throws {
            try self.schema(for: "Face")
        }
    }
    
    private var imageSchema: [String:Any] {
        get throws {
            try self.schema(for: "Image")
        }
    }
    
    private var testImage: UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            var colourIndex: Int = 0
            stride(from: 0, to: 8, by: 4).forEach { y in
                stride(from: 0, to: 8, by: 4).forEach { x in
                    self.testImageColors[colourIndex].setFill()
                    colourIndex += 1
                    context.fill(CGRect(x: x, y: y, width: 4, height: 4))
                }
            }
        }
    }
    
    private var testImageColors: [UIColor] = [.red, .green, .blue, .white]
    
    private var testImagePixels: [UInt8] {
        let colors = self.testImageColors.map { self.bgraFromColor($0) }
        var colorIndex = 0
        var pixels = [[UInt8]]()
        [0,4].forEach { startY in
            (startY..<startY+4).forEach { y in
                var row: [UInt8] = []
                [0,16].forEach { startX in
                    stride(from: startX, to: startX+16, by: 4).forEach { x in
                        row.append(contentsOf: colors[colorIndex])
                    }
                    colorIndex += 1
                }
                pixels.append(row)
            }
        }
        return pixels.flatMap { $0 }
    }
    
    private func bgraFromColor(_ color: UIColor) -> [UInt8] {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return [UInt8(blue*255), UInt8(green*255), UInt8(blue*255), UInt8(alpha*255)]
    }
    
    private func schema(for object: String) throws -> [String:Any] {
        guard let url = Bundle.module.url(forResource: object, withExtension: "json") else {
            throw TestError.genericError
        }
        let schemaData = try Data(contentsOf: url)
        let schema: [String:Any] = try JSONSerialization.jsonObject(with: schemaData) as! [String : Any]
        return schema
    }
    
    private let testFace: Face = Face(bounds: CGRect(x: 10, y: 20.1, width: 30.23, height: 40.7), angle: EulerAngle(yaw: -13.4, pitch: 0.4, roll: 1.3), quality: 9.8, landmarks: [CGPoint(x: 10, y: 20.1), CGPoint(x: 13, y: 20.5)], leftEye: CGPoint(x: 10, y: 20.1), rightEye: CGPoint(x: 13, y: 20.5), noseTip: CGPoint(x: 11.4, y: 23.7), mouthCentre: CGPoint(x: 11.6, y: 26.7))
}

enum TestError: String, Error {
    
    case genericError
}
