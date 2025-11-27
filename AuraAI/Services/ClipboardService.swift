//
//  ClipboardService.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/26/25.
//

import AppKit

final class ClipboardService {
    static let shared = ClipboardService()

    private let pasteboard = NSPasteboard.general

    private init() {}

    /// Reads the current text content from the clipboard
    func readText() -> String? {
        return pasteboard.string(forType: .string)
    }

    /// Writes text to the clipboard
    func writeText(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Checks if clipboard contains text
    func hasText() -> Bool {
        return pasteboard.string(forType: .string) != nil
    }

    /// Gets the change count (useful for monitoring changes)
    var changeCount: Int {
        return pasteboard.changeCount
    }
}
