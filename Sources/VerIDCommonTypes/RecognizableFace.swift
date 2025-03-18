//
//  RecognizableFace.swift
//
//
//  Created by Jakub Dolejs on 23/02/2024.
//

import Foundation

public struct RecognizableFace<T>: Hashable, Sendable, Codable where T: Codable, T: Hashable, T: Sendable {
    
    let face: Face
    let template: T
}
