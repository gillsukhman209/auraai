//
//  FloatingPanelController.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/26/25.
//

import AppKit
import SwiftUI

@Observable
class FloatingPanelController {
    private var panel: FloatingPanel<AnyView>?
    private(set) var isVisible: Bool = false

    func createPanel<Content: View>(content: @escaping () -> Content) {
        let binding = Binding(
            get: { self.isVisible },
            set: { self.isVisible = $0 }
        )

        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let panelWidth = AppConstants.Panel.defaultWidth
        let panelHeight = AppConstants.Panel.defaultHeight

        let contentRect = NSRect(
            x: (screenFrame.width - panelWidth) / 2 + screenFrame.origin.x,
            y: (screenFrame.height - panelHeight) / 2 + screenFrame.origin.y,
            width: panelWidth,
            height: panelHeight
        )

        panel = FloatingPanel(
            isPresented: binding,
            contentRect: contentRect
        ) {
            AnyView(content())
        }

        panel?.minSize = NSSize(
            width: AppConstants.Panel.minWidth,
            height: AppConstants.Panel.minHeight
        )
    }

    func toggle() {
        panel?.toggle()
    }

    func show() {
        panel?.center()
        panel?.makeKeyAndOrderFront(nil)
        isVisible = true
    }

    func hide() {
        panel?.close()
        isVisible = false
    }
}
