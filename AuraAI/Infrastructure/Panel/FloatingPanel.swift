//
//  FloatingPanel.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/26/25.
//

import AppKit
import SwiftUI

class FloatingPanel<Content: View>: NSPanel {
    @Binding var isPresented: Bool

    init(
        isPresented: Binding<Bool>,
        contentRect: NSRect,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._isPresented = isPresented

        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        // Panel behavior
        isFloatingPanel = true
        level = .floating
        collectionBehavior.insert(.fullScreenAuxiliary)
        collectionBehavior.insert(.canJoinAllSpaces)

        // Title bar configuration
        titleVisibility = .hidden
        titlebarAppearsTransparent = true

        // CRITICAL: Full transparency settings
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false  // We'll add shadows on the SwiftUI elements instead

        // Allow moving by dragging background
        isMovableByWindowBackground = true

        // Hide standard window buttons
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        // Create hosting view with transparent background
        let hostingView = NSHostingView(
            rootView: content()
                .ignoresSafeArea()
                .environment(\.floatingPanel, self)
        )

        // Ensure hosting view is also transparent
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = .clear

        contentView = hostingView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func resignMain() {
        super.resignMain()
        // Don't auto-close when losing focus - user might want it to stay
    }

    override func close() {
        super.close()
        isPresented = false
    }

    func toggle() {
        if isVisible {
            close()
        } else {
            center()
            makeKeyAndOrderFront(nil)
            isPresented = true
        }
    }
}

// MARK: - Environment Key for Panel Access

private struct FloatingPanelKey: EnvironmentKey {
    static let defaultValue: NSPanel? = nil
}

extension EnvironmentValues {
    var floatingPanel: NSPanel? {
        get { self[FloatingPanelKey.self] }
        set { self[FloatingPanelKey.self] = newValue }
    }
}
