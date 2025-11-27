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

    // Controllers
    let panelController = FloatingPanelController()
    let hotKeyManager = GlobalHotKeyManager()

    // State
    var conversation = Conversation()

    // Shared screenshot state (set by hotkey, consumed by ChatView)
    // Using array to support multiple screenshots before sending
    var pendingScreenshotsFromHotkey: [NSImage] = []

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
}
