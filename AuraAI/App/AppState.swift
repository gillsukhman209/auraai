//
//  AppState.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/26/25.
//

import AppKit
import Foundation
import SwiftUI

@Observable
class AppState {
    // Services
    let clipboardService = ClipboardService.shared
    let openAIService = OpenAIService()
    let geminiService = GeminiService()
    let screenshotService = ScreenshotService.shared
    let dictionaryService = DictionaryService.shared

    // Controllers
    let panelController = FloatingPanelController()
    let hotKeyManager = GlobalHotKeyManager()

    // State
    var conversation = Conversation()

    // Shared screenshot state (set by hotkey, consumed by ChatView)
    // Using array to support multiple screenshots before sending
    var pendingScreenshotsFromHotkey: [NSImage] = []

    // Shared define word state (set by Cmd+Shift+D hotkey, consumed by ChatView)
    var pendingWordToDefine: String?

    // Shared transform text state (set by Cmd+Shift+T hotkey, consumed by ChatView)
    var pendingTextToTransform: String?

    // Quick summarize state (set by Cmd+Shift+S when text is selected)
    var pendingTextToSummarize: String?

    init() {
        setupHotKeys()
    }

    private func setupHotKeys() {
        // Cmd+Shift+Space - Toggle panel
        hotKeyManager.onHotKeyPressed = { [weak self] in
            self?.panelController.toggle()
        }

        // Cmd+Shift+S - Screenshot
        hotKeyManager.onScreenshotHotKeyPressed = { [weak self] in
            Task { @MainActor in
                await self?.captureAndShowScreenshot()
            }
        }

        // Cmd+Shift+C - Quick summarize selected text
        hotKeyManager.onSummarizeHotKeyPressed = { [weak self] in
            Task { @MainActor in
                await self?.summarizeTextFromSelection()
            }
        }

        // Cmd+Shift+D - Define word from selection (auto-copies highlighted text)
        hotKeyManager.onDefineHotKeyPressed = { [weak self] in
            Task { @MainActor in
                await self?.defineWordFromSelection()
            }
        }

        // Cmd+Shift+T - Transform selected text
        hotKeyManager.onTransformHotKeyPressed = { [weak self] in
            Task { @MainActor in
                await self?.transformTextFromSelection()
            }
        }
    }

    @MainActor
    private func captureAndShowScreenshot() async {
        do {
            // Use native screencapture tool for area selection
            let image = try await screenshotService.captureSelectedArea()
            pendingScreenshotsFromHotkey.append(image)
            panelController.show()
        } catch ScreenshotService.ScreenshotError.cancelled {
            // User cancelled the selection - do nothing
        } catch {
            print("Screenshot hotkey error: \(error.localizedDescription)")
        }
    }

    /// Summarize text from selection (triggered by Cmd+Shift+C)
    /// Same logic as defineWordFromSelection but summarizes instead
    @MainActor
    private func summarizeTextFromSelection() async {
        // Store current clipboard content to detect change
        let previousChangeCount = NSPasteboard.general.changeCount

        // Simulate Cmd+C to copy highlighted text
        simulateCopy()

        // Wait briefly for clipboard to update (up to 200ms)
        var attempts = 0
        while NSPasteboard.general.changeCount == previousChangeCount && attempts < 20 {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            attempts += 1
        }

        // Read clipboard
        guard let text = clipboardService.readText() else { return }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            panelController.show()
            return
        }

        // Set pending text and show panel - ChatView will consume it
        pendingTextToSummarize = trimmed
        panelController.show()
    }

    /// Define word from selection (triggered by Cmd+Shift+D)
    /// Simulates Cmd+C to copy highlighted text, then defines it
    @MainActor
    private func defineWordFromSelection() async {
        // Store current clipboard content to detect change
        let previousChangeCount = NSPasteboard.general.changeCount

        // Simulate Cmd+C to copy highlighted text
        simulateCopy()

        // Wait briefly for clipboard to update (up to 200ms)
        var attempts = 0
        while NSPasteboard.general.changeCount == previousChangeCount && attempts < 20 {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            attempts += 1
        }

        // Read clipboard
        guard let text = clipboardService.readText() else { return }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if it's a single word
        guard dictionaryService.isSingleWord(trimmed) else {
            // Not a single word - still open panel but don't auto-define
            panelController.show()
            return
        }

        // Set pending word and show panel - ChatView will consume it
        pendingWordToDefine = trimmed
        panelController.show()
    }

    /// Transform text from selection (triggered by Cmd+Shift+T)
    /// Simulates Cmd+C to copy highlighted text, then shows transform menu
    @MainActor
    private func transformTextFromSelection() async {
        // Store current clipboard content to detect change
        let previousChangeCount = NSPasteboard.general.changeCount

        // Simulate Cmd+C to copy highlighted text
        simulateCopy()

        // Wait briefly for clipboard to update (up to 200ms)
        var attempts = 0
        while NSPasteboard.general.changeCount == previousChangeCount && attempts < 20 {
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            attempts += 1
        }

        // Read clipboard
        guard let text = clipboardService.readText() else { return }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Need some text to transform
        guard !trimmed.isEmpty else {
            panelController.show()
            return
        }

        // Set pending text and show panel - ChatView will consume it
        pendingTextToTransform = trimmed
        panelController.show()
    }

    /// Simulate Cmd+C keystroke to copy selected text
    private func simulateCopy() {
        // Get frontmost app to send the copy command to
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        let pid = frontApp.processIdentifier

        // Use privateState to avoid interference from currently held modifier keys (Shift)
        let source = CGEventSource(stateID: .privateState)

        // Key code for 'C' is 8
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)

        // Add Cmd modifier (only Cmd, not Shift)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        // Post directly to the frontmost app
        keyDown?.postToPid(pid)
        keyUp?.postToPid(pid)
    }
}
