//
//  QuickAction.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/26/25.
//

import Foundation
import SwiftUI

struct QuickAction: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let prompt: String

    static let actions: [QuickAction] = [
        QuickAction(
            name: "Summarize",
            icon: "doc.text.magnifyingglass",
            color: .blue,
            prompt: "Summarize the following text concisely in 2-3 bullet points:\n\n"
        ),
        QuickAction(
            name: "Explain",
            icon: "lightbulb",
            color: .yellow,
            prompt: "Explain the following in simple terms that anyone can understand:\n\n"
        ),
        QuickAction(
            name: "Rewrite",
            icon: "pencil.line",
            color: .purple,
            prompt: "Rewrite the following text to be clearer and more professional:\n\n"
        ),
        QuickAction(
            name: "Fix Grammar",
            icon: "checkmark.circle",
            color: .green,
            prompt: "Fix any grammar, spelling, or punctuation errors in the following text. Only return the corrected text:\n\n"
        ),
        QuickAction(
            name: "Translate",
            icon: "globe",
            color: .orange,
            prompt: "Translate the following text to English (or if already in English, translate to Spanish):\n\n"
        ),
        QuickAction(
            name: "Make Shorter",
            icon: "arrow.down.right.and.arrow.up.left",
            color: .pink,
            prompt: "Make the following text shorter while keeping the key points:\n\n"
        ),
        QuickAction(
            name: "Make Longer",
            icon: "arrow.up.left.and.arrow.down.right",
            color: .indigo,
            prompt: "Expand the following text with more detail and context:\n\n"
        ),
        QuickAction(
            name: "To Bullets",
            icon: "list.bullet",
            color: .teal,
            prompt: "Convert the following text into a clear bullet point list:\n\n"
        )
    ]
}
