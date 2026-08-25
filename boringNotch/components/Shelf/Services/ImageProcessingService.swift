//
//  ImageProcessingService.swift
//  boringNotch
//
//  Created by Alexander on 2025-10-16.
//

import Foundation
import AppKit
import CoreImage
import CoreGraphics
import Vision
import PDFKit
import UniformTypeIdentifiers
import ImageIO

enum ImageConversionFormat: String, CaseIterable, Identifiable, Sendable {
    case png
    case jpeg
    case heic
    case webP

    var id: String { rawValue }

    var contentType: UTType {
        switch self {
        case .png: .png
        case .jpeg: .jpeg
        case .heic: .heic
        case .webP: .webP
        }
    }

    var fileExtension: String {
        switch self {
        case .jpeg: "jpg"
        case .webP: "webp"
        default: rawValue
        }
    }

    var displayName: String {
        switch self {
        case .webP: "WebP"
        default: rawValue.uppercased()
        }
    }
}

/// Service for processing images (background removal, conversion, PDF creation)
@MainActor
final class ImageProcessingService {
    static let shared = ImageProcessingService()
    
    private init() {}
    private let ciContext = CIContext(options: nil)
    
    // MARK: - Remove Background
    
    /// Removes the background from an image using Vision framework
    func removeBackground(from url: URL) async throws -> URL? {
        guard let inputImage = NSImage(contentsOf: url) else {
            throw ImageProcessingError.invalidImage
        }
        
        guard let cgImage = inputImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw ImageProcessingError.invalidImage
        }
        
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage)
        
        try handler.perform([request])
        
        guard let result = request.results?.first else {
            throw ImageProcessingError.backgroundRemovalFailed
        }
        
        let mask = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
        
        let output = try await applyMask(mask, to: cgImage)
        
        let processedImage = NSImage(cgImage: output, size: inputImage.size)
        
        // Create temporary file
        let originalName = url.deletingPathExtension().lastPathComponent
        let newName = "\(originalName)_no_bg.png"
        
        guard let pngData = processedImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: pngData),
              let finalData = bitmap.representation(using: .png, properties: [:]) else {
            throw ImageProcessingError.saveFailed
        }
        
        guard let tempURL = await TemporaryFileStorageService.shared.createTempFile(
            for: .data(finalData, suggestedName: newName)
        ) else {
            throw ImageProcessingError.saveFailed
        }
        
        return tempURL
    }
    
    private func applyMask(_ mask: CVPixelBuffer, to image: CGImage) async throws -> CGImage {
        let ciImage = CIImage(cgImage: image)
        let maskImage = CIImage(cvPixelBuffer: mask)
        
        let filter = CIFilter.blendWithMask()
        filter.inputImage = ciImage
        filter.maskImage = maskImage
        filter.backgroundImage = CIImage.empty()
        
        guard let output = filter.outputImage else {
            throw ImageProcessingError.backgroundRemovalFailed
        }
        
        let context = CIContext()
        guard let result = context.createCGImage(output, from: output.extent) else {
            throw ImageProcessingError.backgroundRemovalFailed
        }
        
        return result
    }
    
    // MARK: - Convert Image
    
    func supportedOutputFormats(for sourceURL: URL) -> [ImageConversionFormat] {
        let sourceType = sourceURL.accessSecurityScopedResource { url in
            (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType)
        }
        let destinationTypes = Set(
            (CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? []
        )

        return ImageConversionFormat.allCases.filter { format in
            format.contentType != sourceType
                && destinationTypes.contains(format.contentType.identifier)
        }
    }

    func convertImage(
        from sourceURL: URL,
        to format: ImageConversionFormat,
        suggestedName: String
    ) async throws -> URL {
        guard supportedOutputFormats(for: sourceURL).contains(format) else {
            throw ImageProcessingError.unsupportedFormat
        }

        let data = try await Task.detached(priority: .userInitiated) {
            try sourceURL.accessSecurityScopedResource { scopedURL in
                guard let source = CGImageSourceCreateWithURL(scopedURL as CFURL, nil),
                      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
                else {
                    throw ImageProcessingError.invalidImage
                }

                let output = NSMutableData()
                guard let destination = CGImageDestinationCreateWithData(
                    output,
                    format.contentType.identifier as CFString,
                    1,
                    nil
                ) else {
                    throw ImageProcessingError.unsupportedFormat
                }

                let properties: CFDictionary?
                switch format {
                case .jpeg, .heic, .webP:
                    properties = [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary
                case .png:
                    properties = nil
                }

                CGImageDestinationAddImage(destination, image, properties)
                guard CGImageDestinationFinalize(destination) else {
                    throw ImageProcessingError.conversionFailed
                }
                return output as Data
            }
        }.value

        guard let tempURL = await TemporaryFileStorageService.shared.createTempFile(
            for: .data(data, suggestedName: suggestedName)
        ) else {
            throw ImageProcessingError.saveFailed
        }
        return tempURL
    }
    
    // MARK: - Create PDF
    
    /// Creates a PDF from multiple image URLs
    func createPDF(from imageURLs: [URL], outputName: String? = nil) async throws -> URL? {
        guard !imageURLs.isEmpty else {
            throw ImageProcessingError.noImagesProvided
        }
        
        let pdfDocument = PDFDocument()
        
        for (index, url) in imageURLs.enumerated() {
            guard let image = NSImage(contentsOf: url) else {
                continue
            }
            
            let pdfPage = PDFPage(image: image)
            if let page = pdfPage {
                pdfDocument.insert(page, at: index)
            }
        }
        
        guard pdfDocument.pageCount > 0 else {
            throw ImageProcessingError.pdfCreationFailed
        }
        
        // Create temporary file
        let name = outputName ?? "images_\(Date().timeIntervalSince1970).pdf"
        let pdfName = name.hasSuffix(".pdf") ? name : "\(name).pdf"
        
        guard let pdfData = pdfDocument.dataRepresentation() else {
            throw ImageProcessingError.pdfCreationFailed
        }
        
        guard let tempURL = await TemporaryFileStorageService.shared.createTempFile(
            for: .data(pdfData, suggestedName: pdfName)
        ) else {
            throw ImageProcessingError.saveFailed
        }
        
        return tempURL
    }
    
    // MARK: - Helper Methods
    
    /// Checks if a URL is an image file
    func isImageFile(_ url: URL) -> Bool {
        guard let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
            return false
        }
        return contentType.conforms(to: .image)
    }
}

// MARK: - Errors

enum ImageProcessingError: LocalizedError {
    case invalidImage
    case backgroundRemovalFailed
    case conversionFailed
    case unsupportedFormat
    case pdfCreationFailed
    case noImagesProvided
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "The file is not a valid image"
        case .backgroundRemovalFailed:
            return "Failed to remove background from image"
        case .conversionFailed:
            return "Failed to convert image format"
        case .unsupportedFormat:
            return "This image format is not supported by this version of macOS"
        case .pdfCreationFailed:
            return "Failed to create PDF from images"
        case .noImagesProvided:
            return "No images were provided"
        case .saveFailed:
            return "Failed to save processed file"
        }
    }
}
