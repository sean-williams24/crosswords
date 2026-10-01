//
//  CustomKeyboardView.swift
//  Backword
//
//  Created by Sean Williams on 13/05/2026.
//

import SwiftUI

struct CustomKeyboardView: View {
    @ScaledMetric private var rowSpacing: CGFloat = 8
    @ScaledMetric private var keySpacing: CGFloat = 6
    let rows = [
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
        ["Z", "X", "C", "V", "B", "N", "M"]
    ]

    var onKeyTap: (String) -> Void
    var onDelete: () -> Void
    var backgroundColor: Color = .appBackground
    var keyColor: Color = .appSurface
    var specialKeyColor: Color = .appGridLine.opacity(0.8)
    var textColor: Color = .appTextPrimary
    var specialTextColor: Color? = nil

    var body: some View {
        VStack(spacing: rowSpacing) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: keySpacing) {
                    ForEach(row, id: \.self) { char in
                        Button(char) { onKeyTap(char) }
                            .buttonStyle(KeyButtonStyle(keyColor: keyColor, specialKeyColor: specialKeyColor, textColor: textColor))
                    }

                    // Add the delete button to the bottom row
                    if row == rows.last {
                        Button(action: onDelete) {
                            Image(systemName: "delete.left")
                        }
                        .buttonStyle(KeyButtonStyle(isSpecial: true, keyColor: keyColor, specialKeyColor: specialKeyColor, textColor: textColor, specialTextColor: specialTextColor))
                    }
                }
            }
        }
        .padding()
        .background(backgroundColor)
    }
}

struct KeyButtonStyle: ButtonStyle {
    var isSpecial: Bool = false
    var keyColor: Color = .appSurface
    var specialKeyColor: Color = .appGridLine.opacity(0.8)
    var textColor: Color = .appTextPrimary
    var specialTextColor: Color? = nil
    @ScaledMetric private var keyHeight: CGFloat = 45
    @ScaledMetric private var fontSize: CGFloat = 20

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(AppFont.gridLetter(fontSize))
            .minimumScaleFactor(0.6)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .frame(height: keyHeight)
            .background(isSpecial ? specialKeyColor : keyColor)
            .foregroundColor(isSpecial ? (specialTextColor ?? textColor) : textColor)
            .cornerRadius(6)
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
    }
}

#Preview {
    CustomKeyboardView(onKeyTap: {_ in }, onDelete: {})
}
