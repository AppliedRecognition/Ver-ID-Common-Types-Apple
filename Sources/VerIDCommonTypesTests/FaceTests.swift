import XCTest
@testable import VerIDCommonTypes

final class FaceTests: XCTestCase {
    
    func testCreateFace() {
        _ = Face(bounds: .zero, angle: .identity, quality: 10, landmarks: [], leftEye: .zero, rightEye: .zero)
    }
    
    func testSortFaces() {
        let rects: [CGRect] = [
            CGRect(x: 0, y: 1, width: 30, height: 50),
            CGRect(x: 20, y: 10, width: 100, height: 150),
            CGRect(x: 20, y: 30, width: 300, height: 450),
            CGRect(x: 0, y: 1, width: 30, height: 50)
        ]
        let qualities: [Float] = [
            10, 9, 8, 1
        ]
        let faces = zip(rects, qualities).map {
            Face(bounds: $0.0, angle: .identity, quality: $0.1, landmarks: [], leftEye: .zero, rightEye: .zero)
        }
        let sortedFaces = faces.sorted()
        let manuallySorted = faces.sorted(by: { (face1: Face, face2: Face) in
            let face1Order = face1.bounds.width * face1.bounds.height * CGFloat(face1.quality)
            let face2Order = face2.bounds.width * face2.bounds.height * CGFloat(face2.quality)
            return face1Order > face2Order
        })
        XCTAssertEqual(sortedFaces, manuallySorted)
    }
    
    func testApplyMirrorTransform() {
        let width: CGFloat = 400
        let face = Face(bounds: CGRect(x: 10, y: 20, width: 200, height: 300), angle: .identity, quality: 10, landmarks: [CGPoint(x: 60, y: 120), CGPoint(x: 160, y: 120)], leftEye: CGPoint(x: 60, y: 120), rightEye: CGPoint(x: 160, y: 120), noseTip: CGPoint(x: 130, y: 200), mouthCentre: CGPoint(x: 131, y: 240))
        let mirrorTransform = CGAffineTransform.horizontalMirror(in: width)
        let mirroredFace = face.applying(mirrorTransform)
        XCTAssertEqual(mirroredFace.bounds.minX, width - face.bounds.maxX)
        XCTAssertEqual(mirroredFace.bounds.minY, 20)
        XCTAssertEqual(mirroredFace.bounds.width, face.bounds.width)
        XCTAssertEqual(mirroredFace.bounds.height, face.bounds.height)
        XCTAssertEqual(mirroredFace.landmarks[0].x, width - face.landmarks[0].x)
        XCTAssertEqual(mirroredFace.landmarks[0].y, face.landmarks[0].y)
        XCTAssertEqual(mirroredFace.landmarks[1].x, width - face.landmarks[1].x)
        XCTAssertEqual(mirroredFace.landmarks[1].y, face.landmarks[1].y)
        XCTAssertEqual(mirroredFace.leftEye.x, width - face.leftEye.x)
        XCTAssertEqual(mirroredFace.leftEye.y, face.leftEye.y)
        XCTAssertEqual(mirroredFace.rightEye.x, width - face.rightEye.x)
        XCTAssertEqual(mirroredFace.rightEye.y, face.rightEye.y)
        XCTAssertEqual(mirroredFace.noseTip!.x, width - face.noseTip!.x)
        XCTAssertEqual(mirroredFace.noseTip!.y, face.noseTip!.y)
        XCTAssertEqual(mirroredFace.mouthCentre!.x, width - face.mouthCentre!.x)
        XCTAssertEqual(mirroredFace.mouthCentre!.y, face.mouthCentre!.y)
    }
    
    func testChangeFaceAspectRatio() {
        let face = Face(bounds: CGRect(x: 10, y: 20, width: 200, height: 200), angle: .identity, quality: 10, landmarks: [], leftEye: .zero, rightEye: .zero)
        let aspectRatio: CGFloat = 4/5
        let changedFace = face.withBoundsSetToAspectRatio(aspectRatio)
        XCTAssertEqual(changedFace.bounds.aspectRatio, aspectRatio, accuracy: 0.01)
        XCTAssertEqual(changedFace.bounds.height, face.bounds.height / aspectRatio, accuracy: 0.01)
    }
}
