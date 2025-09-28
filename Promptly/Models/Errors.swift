//
//  Errors.swift
//  Promptly
//
//  Created by Sasha Bagrov on 14/06/2025.
//

import Foundation

enum PDFProcessingError: LocalizedError {
    case accessDenied
    case invalidPDF
    case processingFailed
    
    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Unable to access the selected PDF file"
        case .invalidPDF:
            return "The selected file is not a valid PDF"
        case .processingFailed:
            return "Failed to process the PDF content"
        }
    }
}
