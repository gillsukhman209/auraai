//
//  TimerWindowController.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/28/25.
//

import AppKit
import SwiftUI

class TimerWindowController: NSWindowController {

    convenience init() {
        // Create a resizable floating window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 220, height: 300),
            styleMask: [.borderless, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        self.init(window: window)

        // Configure window properties
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false  // We use SwiftUI shadow instead
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.isMovableByWindowBackground = true

        // Set size constraints
        window.minSize = NSSize(width: 180, height: 240)
        window.maxSize = NSSize(width: 400, height: 500)

        // Set the SwiftUI view as content
        let hostingView = NSHostingView(rootView: TimerView())
        hostingView.layer?.backgroundColor = .clear
        window.contentView = hostingView

        // Position in bottom-right corner
        positionWindow()
    }

    private func positionWindow() {
        guard let screen = NSScreen.main, let window = window else { return }

        let screenFrame = screen.visibleFrame
        let windowSize = window.frame.size

        let x = screenFrame.maxX - windowSize.width - 20
        let y = screenFrame.minY + 20

        window.setFrameOrigin(NSPoint(x: x, y: y))
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
    }
}
