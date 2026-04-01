import SwiftUI

struct BackwordLetterCell: View {
    let letter: Character?       // Permanently revealed target letter
    var inputLetter: Character?  // Currently typed letter (unrevealed position)
    var isCursor: Bool = false   // Active input position (next to type)
    var isNew: Bool = false
    var size: CGFloat = 44

    @State private var flashed = false

    private var displayLetter: Character? { letter ?? inputLetter }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(cellBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(cellBorder, lineWidth: isCursor ? 2 : 1.5)
                )

            if let ch = displayLetter {
                Text(String(ch))
                    .font(AppFont.gridLetter(size * 0.45))
                    .foregroundColor(.appTextPrimary)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            } else if isCursor {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.appAccent)
                    .frame(width: 2, height: size * 0.42)
            } else {
                Text("_")
                    .font(AppFont.gridLetter(size * 0.38))
                    .foregroundColor(.appTextSecondary.opacity(0.4))
            }
        }
        .frame(width: size, height: size)
        .onChange(of: isNew) { newValue in
            guard newValue else { return }
            flashed = true
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                flashed = false
            }
        }
    }

    private var cellBackground: Color {
        if flashed { return .appAccent.opacity(0.25) }
        if letter != nil { return .appSurface }
        if inputLetter != nil { return .appSurface }
        return .appSurface.opacity(0.5)
    }

    private var cellBorder: Color {
        if flashed { return .appAccent }
        if letter != nil { return .appAccent.opacity(0.5) }
        if inputLetter != nil { return .appTextPrimary.opacity(0.5) }
        if isCursor { return .appAccent }
        return .appGridLine
    }
}
