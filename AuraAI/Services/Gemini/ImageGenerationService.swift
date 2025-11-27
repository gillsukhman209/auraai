//
//  ImageGenerationService.swift
//  AuraAI
//
//  Created by Claude on 11/27/25.
//

import AppKit
import Foundation

enum ImageGenerationError: Error, LocalizedError {
    case noAPIKey
    case invalidAPIKey
    case networkError(Error)
    case decodingError(Error)
    case apiError(String)
    case noImageGenerated
    case contentBlocked(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No Gemini API key configured for image generation."
        case .invalidAPIKey:
            return "Invalid Gemini API key."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .apiError(let message):
            return "API error: \(message)"
        case .noImageGenerated:
            return "No image was generated."
        case .contentBlocked(let reason):
            return "Image generation blocked: \(reason)"
        }
    }
}

actor ImageGenerationService {
    static let shared = ImageGenerationService()

    private var apiKey: String {
        AppConstants.API.geminiAPIKey
    }

    // Use Gemini native image generation (Nano Banana Pro)
    private var generateURL: URL {
        URL(string: "\(AppConstants.API.geminiBaseURL)/\(AppConstants.API.imagenModel):generateContent?key=\(apiKey)")!
    }

    private init() {}

    /// Generate an image from a text prompt using Gemini native image generation
    /// - Parameter prompt: The text description of the image to generate
    /// - Returns: The generated NSImage
    func generateImage(prompt: String) async throws -> NSImage {
        guard !apiKey.isEmpty && !apiKey.contains("YOUR_") else {
            throw ImageGenerationError.noAPIKey
        }

        // Debug: Log model being used
        print("🖼️ Image Generation - Model: \(AppConstants.API.imagenModel)")
        print("🖼️ Image Generation - URL: \(generateURL.absoluteString.replacingOccurrences(of: apiKey, with: "***API_KEY***"))")
        print("🖼️ Image Generation - Prompt: \(prompt)")

        var urlRequest = URLRequest(url: generateURL)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Use Gemini generateContent API with image output modality
        let request = GeminiImageGenRequest(
            contents: [
                GeminiImageGenContent(
                    parts: [GeminiImageGenPart(text: prompt)]
                )
            ],
            generationConfig: GeminiImageGenConfig(
                responseModalities: ["TEXT", "IMAGE"]
            )
        )

        urlRequest.httpBody = try JSONEncoder().encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ImageGenerationError.networkError(URLError(.badServerResponse))
        }

        print("🖼️ Image Generation - HTTP Status: \(httpResponse.statusCode)")

        guard httpResponse.statusCode == 200 else {
            if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                throw ImageGenerationError.invalidAPIKey
            }

            // Try to parse error message
            if let errorResponse = try? JSONDecoder().decode(GeminiImageGenErrorResponse.self, from: data) {
                print("🖼️ Image Generation - Error: \(errorResponse.error.message)")
                throw ImageGenerationError.apiError(errorResponse.error.message)
            }

            // Log raw response for debugging
            if let rawResponse = String(data: data, encoding: .utf8) {
                print("🖼️ Image Generation - Raw Error Response: \(rawResponse.prefix(500))")
            }

            throw ImageGenerationError.apiError("HTTP \(httpResponse.statusCode)")
        }

        // Parse the response
        let geminiResponse = try JSONDecoder().decode(GeminiImageGenResponse.self, from: data)

        // Find the image part in the response
        guard let candidate = geminiResponse.candidates?.first,
              let content = candidate.content,
              let imagePart = content.parts.first(where: { $0.inlineData != nil }),
              let inlineData = imagePart.inlineData,
              let base64Image = inlineData.data else {
            throw ImageGenerationError.noImageGenerated
        }

        // Convert base64 to NSImage
        guard let imageData = Data(base64Encoded: base64Image),
              let image = NSImage(data: imageData) else {
            throw ImageGenerationError.decodingError(
                NSError(domain: "ImageGenerationService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to decode image data"])
            )
        }

        print("🖼️ Image Generation - Success! Image size: \(image.size)")
        return image
    }
}

// MARK: - Request Models

struct GeminiImageGenRequest: Encodable {
    let contents: [GeminiImageGenContent]
    let generationConfig: GeminiImageGenConfig
}

struct GeminiImageGenContent: Encodable {
    let parts: [GeminiImageGenPart]
}

struct GeminiImageGenPart: Encodable {
    let text: String?

    init(text: String) {
        self.text = text
    }
}

struct GeminiImageGenConfig: Encodable {
    let responseModalities: [String]
}

// MARK: - Response Models

struct GeminiImageGenResponse: Decodable {
    let candidates: [GeminiImageGenCandidate]?
}

struct GeminiImageGenCandidate: Decodable {
    let content: GeminiImageGenResponseContent?
    let finishReason: String?
}

struct GeminiImageGenResponseContent: Decodable {
    let parts: [GeminiImageGenResponsePart]
    let role: String?
}

struct GeminiImageGenResponsePart: Decodable {
    let text: String?
    let inlineData: GeminiImageGenInlineData?

    enum CodingKeys: String, CodingKey {
        case text
        case inlineData = "inlineData"
    }
}

struct GeminiImageGenInlineData: Decodable {
    let mimeType: String?
    let data: String?
}

// MARK: - Error Models

struct GeminiImageGenErrorResponse: Decodable {
    let error: GeminiImageGenErrorDetail
}

struct GeminiImageGenErrorDetail: Decodable {
    let code: Int?
    let message: String
    let status: String?
}
