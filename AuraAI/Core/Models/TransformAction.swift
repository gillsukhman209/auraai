//
//  TransformAction.swift
//  AuraAI
//
//  Created by Claude on 11/28/25.
//

import Foundation

/// Actions available for transforming selected text
enum TransformAction: String, CaseIterable, Identifiable {
    case fixGrammar
    case makeShorter
    case makeLonger
    case simplify
    case makeProfessional
    case makeCasual
    case summarize
    case explain
    case translateSpanish
    case translateFrench
    case translateGerman
    case translateChinese

    var id: String { rawValue }

    var name: String {
        switch self {
        case .fixGrammar: return "Fix Grammar"
        case .makeShorter: return "Make Shorter"
        case .makeLonger: return "Make Longer"
        case .simplify: return "Simplify"
        case .makeProfessional: return "Professional"
        case .makeCasual: return "Casual"
        case .summarize: return "Summarize"
        case .explain: return "Explain"
        case .translateSpanish: return "Spanish"
        case .translateFrench: return "French"
        case .translateGerman: return "German"
        case .translateChinese: return "Chinese"
        }
    }

    var icon: String {
        switch self {
        case .fixGrammar: return "checkmark.circle"
        case .makeShorter: return "arrow.down.right.and.arrow.up.left"
        case .makeLonger: return "arrow.up.left.and.arrow.down.right"
        case .simplify: return "lightbulb"
        case .makeProfessional: return "briefcase"
        case .makeCasual: return "face.smiling"
        case .summarize: return "list.bullet"
        case .explain: return "questionmark.circle"
        case .translateSpanish, .translateFrench, .translateGerman, .translateChinese: return "globe"
        }
    }

    var prompt: String {
        switch self {
        case .fixGrammar:
            return "Fix any grammar and spelling errors in this text. Keep the same tone and meaning. Only output the corrected text, nothing else:\n\n"
        case .makeShorter:
            return "Make this text shorter while keeping the key points. Only output the shortened text, nothing else:\n\n"
        case .makeLonger:
            return "Expand this text with more detail while keeping the same style. Only output the expanded text, nothing else:\n\n"
        case .simplify:
            return "Rewrite this in simpler terms that anyone can easily understand. Only output the simplified text, nothing else:\n\n"
        case .makeProfessional:
            return "Rewrite this in a professional, formal tone. Only output the rewritten text, nothing else:\n\n"
        case .makeCasual:
            return "Rewrite this in a friendly, casual tone. Only output the rewritten text, nothing else:\n\n"
        case .summarize:
            return "Summarize the key points in 2-3 bullet points:\n\n"
        case .explain:
            return "Explain what this text means in simple terms:\n\n"
        case .translateSpanish:
            return "Translate to Spanish. Only output the translation, nothing else:\n\n"
        case .translateFrench:
            return "Translate to French. Only output the translation, nothing else:\n\n"
        case .translateGerman:
            return "Translate to German. Only output the translation, nothing else:\n\n"
        case .translateChinese:
            return "Translate to Chinese. Only output the translation, nothing else:\n\n"
        }
    }

    /// Main actions (not translations)
    static var mainActions: [TransformAction] {
        [.fixGrammar, .makeShorter, .makeLonger, .simplify, .makeProfessional, .makeCasual, .summarize, .explain]
    }

    /// Translation actions
    static var translateActions: [TransformAction] {
        [.translateSpanish, .translateFrench, .translateGerman, .translateChinese]
    }
}
