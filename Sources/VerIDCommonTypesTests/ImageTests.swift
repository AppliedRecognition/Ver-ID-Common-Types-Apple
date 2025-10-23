//
//  ImageTests.swift
//  VerIDCommonTypes
//
//  Created by Jakub Dolejs on 23/10/2025.
//

import Testing
import UIKit
@testable import VerIDCommonTypes

struct ImageTests {

    @Test func testCreateImageFromUIImage() throws {
        guard let url = Bundle.module.url(forResource: "Image", withExtension: "heic") else {
            throw TestError.genericError
        }
        let data = try Data(contentsOf: url)
        guard let uiImage = UIImage(data: data) else {
            throw TestError.genericError
        }
        _ = try uiImage.toVerIDImage()
    }

    @Test func testCreateImageFromCGImage() throws {
        guard let url = Bundle.module.url(forResource: "Image", withExtension: "heic") else {
            throw TestError.genericError
        }
        let data = try Data(contentsOf: url)
        guard let uiImage = UIImage(data: data), let cgImage = uiImage.cgImage else {
            throw TestError.genericError
        }
        #expect(Image(cgImage: cgImage, orientation: uiImage.imageOrientation.cgImagePropertyOrientation) != nil)
    }
}
