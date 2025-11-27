//
//  SettingsView.swift
//  AuraAI
//
//  Created by Sukhman Singh on 11/26/25.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("AuraAI Settings")
                .font(.title2)
                .fontWeight(.semibold)

            GroupBox("Keyboard Shortcut") {
                HStack {
                    Text("Open AuraAI:")
                    Spacer()
                    Text("Cmd + Shift + Space")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }

            GroupBox("About") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Version:")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("AI Model:")
                        Spacer()
                        Text("GPT-4o")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Spacer()
        }
        .padding(20)
        .frame(width: 350, height: 250)
    }
}

#Preview {
    SettingsView()
}
