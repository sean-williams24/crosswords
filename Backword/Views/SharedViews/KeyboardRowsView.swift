import SwiftUI

/// Keeps scaled spacing below the keyboard's Dynamic Type boundary.
struct KeyboardRowsView: View {
    @ScaledMetric private var rowSpacing: CGFloat = 8
    @ScaledMetric private var keySpacing: CGFloat = 6

    private let rows = [
        ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
        ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
        ["Z", "X", "C", "V", "B", "N", "M"]
    ]

    var onKeyTap: (String) -> Void
    var onDelete: () -> Void
    var keyColor: Color
    var specialKeyColor: Color
    var textColor: Color
    var specialTextColor: Color?

    var body: some View {
        VStack(spacing: rowSpacing) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: keySpacing) {
                    ForEach(row, id: \.self) { char in
                        Button(char) { onKeyTap(char) }
                            .buttonStyle(KeyButtonStyle(keyColor: keyColor, specialKeyColor: specialKeyColor, textColor: textColor))
                    }

                    if row == rows.last {
                        Button(action: onDelete) {
                            Image(systemName: "delete.left")
                        }
                        .buttonStyle(KeyButtonStyle(isSpecial: true, keyColor: keyColor, specialKeyColor: specialKeyColor, textColor: textColor, specialTextColor: specialTextColor))
                    }
                }
            }
        }
    }
}
