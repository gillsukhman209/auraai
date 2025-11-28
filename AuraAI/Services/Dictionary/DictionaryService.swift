//
//  DictionaryService.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/28/25.
//

import Foundation

/// Result from dictionary lookup
struct DictionaryResult {
    let word: String
    let definition: String
    let example: String?

    /// Format the result for display in chat - clean and readable
    var formattedResponse: String {
        var response = "**\(word.capitalized)**\n\n"
        response += definition

        if let ex = example {
            response += "\n\n_\"\(ex)\"_"
        }

        return response
    }
}

/// Service for looking up word definitions using macOS built-in dictionary
struct DictionaryService {
    static let shared = DictionaryService()

    private init() {}

    /// Look up a word in the macOS dictionary
    /// - Parameter word: The word to define
    /// - Returns: DictionaryResult if found, nil otherwise
    func define(_ word: String) -> DictionaryResult? {
        let trimmedWord = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard !trimmedWord.isEmpty else { return nil }

        // Use macOS DictionaryServices API
        guard let definition = DCSCopyTextDefinition(nil, trimmedWord as CFString, CFRangeMake(0, trimmedWord.count)) else {
            return nil
        }

        let rawText = definition.takeRetainedValue() as String

        // Parse the raw definition into structured components
        return parseDefinition(word: trimmedWord, rawText: rawText)
    }

    /// Parse raw dictionary text into structured result
    private func parseDefinition(word: String, rawText: String) -> DictionaryResult {
        var text = rawText

        // Remove the word itself from the start if present
        if text.lowercased().hasPrefix(word.lowercased()) {
            text = String(text.dropFirst(word.count)).trimmingCharacters(in: .whitespaces)
        }

        // Skip past part of speech labels (we don't display them)
        let partsOfSpeech = ["noun", "verb", "adjective", "adverb", "pronoun", "preposition", "conjunction", "interjection", "exclamation"]
        for pos in partsOfSpeech {
            if text.lowercased().hasPrefix(pos) {
                text = String(text.dropFirst(pos.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }

        // Remove everything after these markers (not helpful)
        let cutoffMarkers = ["ANTONYMS", "SYNONYMS", "WORD LINKS", "ORIGIN", "DERIVATIVES", "PHRASES", "• ", "1 ", "2 "]
        for marker in cutoffMarkers {
            if let range = text.range(of: marker, options: .caseInsensitive) {
                text = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
        }

        // Try to extract one clean example
        var example: String?
        var definition: String

        // Split by colon first - often "definition: example"
        if let colonRange = text.range(of: ": ") {
            let beforeColon = String(text[..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let afterColon = String(text[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)

            // After colon is usually an example if it contains the word
            if afterColon.lowercased().contains(word.lowercased()) {
                definition = extractCoreDefinition(from: beforeColon)
                example = cleanExample(afterColon)
            } else {
                definition = extractCoreDefinition(from: text)
            }
        } else {
            // Split by period to get sentences
            let sentences = text.components(separatedBy: ". ")

            if sentences.count >= 2 {
                let firstPart = sentences[0].trimmingCharacters(in: .whitespaces)
                let secondPart = sentences.dropFirst().joined(separator: ". ").trimmingCharacters(in: .whitespaces)

                // If first part contains the word (example usage), use second as definition
                if firstPart.lowercased().contains(word.lowercased()) && !secondPart.isEmpty {
                    example = cleanExample(firstPart)
                    definition = extractCoreDefinition(from: secondPart)
                } else {
                    definition = extractCoreDefinition(from: firstPart)
                    if secondPart.lowercased().contains(word.lowercased()) {
                        example = cleanExample(secondPart)
                    }
                }
            } else {
                definition = extractCoreDefinition(from: text)
            }
        }

        // Final cleanup
        definition = definition.trimmingCharacters(in: .whitespaces)
        while definition.hasSuffix(".") || definition.hasSuffix(":") {
            definition = String(definition.dropLast())
        }

        // Capitalize first letter
        if let first = definition.first {
            definition = first.uppercased() + definition.dropFirst()
        }

        return DictionaryResult(
            word: word,
            definition: definition,
            example: example
        )
    }

    /// Extract just the core definition, removing synonym lists
    private func extractCoreDefinition(from text: String) -> String {
        var result = text

        // Remove semicolon-separated synonym lists
        if let semicolonIndex = result.firstIndex(of: ";") {
            result = String(result[..<semicolonIndex])
        }

        // If there's a long comma-separated list (synonyms), cut it off
        let commaCount = result.filter { $0 == "," }.count
        if commaCount >= 3 {
            // This is likely a synonym list - try to find the actual definition before it
            let parts = result.components(separatedBy: ", ")
            if parts.count > 0 {
                // Take only the first part if others look like single-word synonyms
                let firstPart = parts[0]
                let otherParts = parts.dropFirst()
                let allOthersAreSingleWords = otherParts.allSatisfy { !$0.contains(" ") || $0.count < 15 }
                if allOthersAreSingleWords && firstPart.contains(" ") {
                    result = firstPart
                }
            }
        }

        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Clean up an example sentence
    private func cleanExample(from text: String) -> String? {
        var example = text.trimmingCharacters(in: .whitespaces)

        // Remove trailing punctuation artifacts
        while example.hasSuffix(".") || example.hasSuffix(",") || example.hasSuffix(";") {
            example = String(example.dropLast())
        }

        // If too long, skip it
        if example.count > 100 {
            return nil
        }

        return example.isEmpty ? nil : example
    }

    private func cleanExample(_ text: String) -> String? {
        return cleanExample(from: text)
    }

    /// Check if a message is a dictionary request
    /// Returns the word to define if it matches a pattern, nil otherwise
    func extractWordToDefine(from message: String) -> String? {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Pattern: "define word"
        if let match = trimmed.range(of: #"^define\s+(.+)$"#, options: .regularExpression) {
            let afterDefine = String(trimmed[match]).replacingOccurrences(of: "define ", with: "")
            return extractFirstWord(from: afterDefine)
        }

        // Pattern: "what does word mean"
        if trimmed.range(of: #"^what does (.+) mean\??$"#, options: .regularExpression) != nil {
            let word = trimmed
                .replacingOccurrences(of: "what does ", with: "")
                .replacingOccurrences(of: " mean", with: "")
                .replacingOccurrences(of: "?", with: "")
            return extractFirstWord(from: word)
        }

        // Pattern: "word meaning" or "meaning of word"
        if trimmed.range(of: #"^(.+)\s+meaning$"#, options: .regularExpression) != nil {
            let word = trimmed.replacingOccurrences(of: " meaning", with: "")
            return extractFirstWord(from: word)
        }

        if trimmed.hasPrefix("meaning of ") {
            let word = trimmed.replacingOccurrences(of: "meaning of ", with: "")
            return extractFirstWord(from: word)
        }

        // Pattern: "what is word" or "what's word"
        if trimmed.hasPrefix("what is ") || trimmed.hasPrefix("what's ") {
            let word = trimmed
                .replacingOccurrences(of: "what is ", with: "")
                .replacingOccurrences(of: "what's ", with: "")
                .replacingOccurrences(of: "?", with: "")
            // Only match single words (not questions like "what is the weather")
            let firstWord = extractFirstWord(from: word)
            if firstWord == word.trimmingCharacters(in: .whitespaces) {
                return firstWord
            }
        }

        return nil
    }

    /// Check if clipboard text is a single word suitable for definition
    func isSingleWord(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Must be a reasonable length
        guard trimmed.count >= 2 && trimmed.count <= 30 else { return false }

        // Must not contain spaces (single word only)
        guard !trimmed.contains(" ") else { return false }

        // Must contain only letters (and optionally hyphens for compound words)
        let allowedCharacters = CharacterSet.letters.union(CharacterSet(charactersIn: "-"))
        guard trimmed.unicodeScalars.allSatisfy({ allowedCharacters.contains($0) }) else { return false }

        return true
    }

    // MARK: - Private Helpers

    private func extractFirstWord(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let spaceIndex = trimmed.firstIndex(of: " ") {
            return String(trimmed[..<spaceIndex])
        }
        return trimmed
    }
}
