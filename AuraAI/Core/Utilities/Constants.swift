//
//  Constants.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/26/25.
//

import Foundation
import AppKit

enum AppConstants {
    static let appName = "AuraAI"

    enum Panel {
        static let defaultWidth: CGFloat = 400
        static let defaultHeight: CGFloat = 500
        static let minWidth: CGFloat = 300
        static let minHeight: CGFloat = 200
    }

    enum API {
        // MARK: - OpenAI API Configuration
        // API key is loaded from Secrets.swift (gitignored)
        static let openAIAPIKey = Secrets.openAIAPIKey
        static let openAIBaseURL = "https://api.openai.com/v1/chat/completions"
        static let openAIModel = "gpt-4o"
        static let maxTokens = 4096

        // MARK: - Gemini API Configuration
        static let geminiAPIKey = Secrets.geminiAPIKey
        static let geminiBaseURL = "https://generativelanguage.googleapis.com/v1beta/models"
        static let geminiModel = "gemini-2.0-flash"

        // MARK: - Gemini Image Generation (Nano Banana Pro - Released Nov 20, 2025)
        static let imagenModel = "gemini-3-pro-image-preview"
    }

    enum HotKey {
        // Default: Command + Shift + Space
        static let defaultKeyCode: UInt32 = 49  // Space key
        static let defaultModifiers: UInt32 = 768  // Command + Shift
    }
}
