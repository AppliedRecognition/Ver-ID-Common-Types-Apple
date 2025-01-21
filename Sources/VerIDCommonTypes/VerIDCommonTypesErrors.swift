//
//  Errors.swift
//
//
//  Created by Jakub Dolejs on 21/02/2024.
//

import Foundation

public enum ImageError: Error, CustomStringConvertible, LocalizedError {
    
    case imageConversionFailed
    case imageRotationFailed
    
    public var description: String {
        switch self {
        case .imageConversionFailed:
            return "Image conversion failed"
        case .imageRotationFailed:
            return "Image rotation failed"
        }
    }
    
    public var localizedDescription: String {
        NSLocalizedString(self.description, comment: "")
    }
}
