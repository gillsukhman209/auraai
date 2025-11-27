//
//  AppState.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/26/25.
//

import Foundation
import SwiftUI

@Observable
class AppState {
    // Services
    let clipboardService = ClipboardService.shared
    let openAIService = OpenAIService()

    // Controllers
    let panelController = FloatingPanelController()
    let hotKeyManager = GlobalHotKeyManager()

    // State
    var conversation = Conversation()

    init() {
        setupHotKey()
    }

    private func setupHotKey() {
        hotKeyManager.onHotKeyPressed = { [weak self] in
            self?.panelController.toggle()
        }
    }
}
