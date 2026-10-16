//
//  CustomKeyboardView.swift
//  Backword
//
//  Created by Sean Williams on 13/05/2026.
//

import SwiftUI

struct CustomKeyboardView: View {
    var onKeyTap: (String) -> Void
    var onDelete: () -> Void
    var backgroundColor: Color = .appBackground
    var keyColor: Color = .appSurface
    var specialKeyColor: Color = .appGridLine.opacity(0.8)
    var textColor: Color = .appTextPrimary
    var specialTextColor: Color? = nil

    var body: some View {
        GameDynamicTypeContainer {
            KeyboardRowsView(
                onKeyTap: onKeyTap,
                onDelete: onDelete,
                keyColor: keyColor,
                specialKeyColor: specialKeyColor,
                textColor: textColor,
                specialTextColor: specialTextColor
            )
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
