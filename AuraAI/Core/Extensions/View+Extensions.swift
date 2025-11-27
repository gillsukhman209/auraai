//
//  View+Extensions.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/26/25.
//

import SwiftUI

extension View {
    /// Applies a subtle shadow for floating elements
    func floatingShadow() -> some View {
        self.shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }

    /// Applies the transparent panel background
    func panelBackground() -> some View {
        self.background(.ultraThinMaterial)
    }
}
