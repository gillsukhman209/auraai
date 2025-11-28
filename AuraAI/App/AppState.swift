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

    init() {
        setupHotKeys()
    }

    private func setupHotKeys() {
        // Cmd+Shift+Space - Toggle panel
        hotKeyManager.onHotKeyPressed = { [weak self] in
            self?.panelController.toggle()
        }

        // Cmd+Shift+S - Quick screenshot
        hotKeyManager.onScreenshotHotKeyPressed = { [weak self] in
            Task { @MainActor in
                await self?.captureAndShowScreenshot()
            }
        }

        // Cmd+Shift+D - Define word from selection (auto-copies highlighted text)
        hotKeyManager.onDefineHotKeyPressed = { [weak self] in
            Task { @MainActor in
                await self?.defineWordFromSelection()
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

    /// Simulate Cmd+C keystroke to copy selected text
    private func simulateCopy() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key code for 'C' is 8
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)

        // Add Cmd modifier
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        // Post the events
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
