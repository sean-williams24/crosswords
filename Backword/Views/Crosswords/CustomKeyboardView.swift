//
//  CustomKeyboardView.swift
//  Backword
//
//  Created by Sean Williams on 13/05/2026.
//

import SwiftUI

struct CustomKeyboardView: View {
    let rows = [
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
        ["Z", "X", "C", "V", "B", "N", "M"]
    ]

    var onKeyTap: (String) -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { char in
                        Button(char) { onKeyTap(char) }
                            .buttonStyle(KeyButtonStyle())
                    }

                    // Add the delete button to the bottom row
                    if row == rows.last {
                        Button(action: onDelete) {
                            Image(systemName: "delete.left")
                        }
                        .buttonStyle(KeyButtonStyle(isSpecial: true))
                    }
                }
            }
        }
        .padding()
        .background(Color.appBackground)
    }
}

struct KeyButtonStyle: ButtonStyle {
    var isSpecial: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.gridLetter())
            .frame(maxWidth: .infinity)
            .frame(height: 45)
            .background(isSpecial ? Color.appGridLine.opacity(0.8) : Color.appSurface)
            .foregroundColor(.appTextPrimary)
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
    }
}

#Preview {
    CustomKeyboardView(onKeyTap: {_ in }, onDelete: {})
}
