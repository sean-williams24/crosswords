import SwiftUI

struct BackwordLetterCell: View {
    let letter: Character?
    var inputLetter: Character?
    var isCursor: Bool = false
    var isNew: Bool = false
    var size: CGFloat = 44

    @State private var flashed = false

    private var displayLetter: Character? { letter ?? inputLetter }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(cellBackground)

            // Border — pulsing sub-view when cursor, static otherwise
            if isCursor {
                PulsingBorder(size: size, cornerRadius: 6)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(staticBorderColor, lineWidth: 1.5)
            }

            if let ch = displayLetter {
                Text(String(ch))
                    .font(AppFont.gridLetter(size * 0.45))
                    .foregroundColor(.appTextPrimary)
                    .transition(.scale(scale: 0.4).combined(with: .opacity))
            } else if isCursor {
                PulsingUnderscore(size: size)
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
        if letter != nil || inputLetter != nil { return .appSurface }
        return .appSurface.opacity(0.5)
    }

    private var staticBorderColor: Color {
        if flashed { return .appAccent }
        if letter != nil { return .appAccent.opacity(0.5) }
        if inputLetter != nil { return .appTextPrimary.opacity(0.5) }
        return .appGridLine
    }
}

// MARK: - Pulsing sub-views (only in hierarchy when isCursor == true)

private struct PulsingBorder: View {
    let size: CGFloat
    let cornerRadius: CGFloat
    @State private var pulse = false

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(Color.appAccent.opacity(pulse ? 1 : 0.4), lineWidth: pulse ? 2 : 1.5)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}

private struct PulsingUnderscore: View {
    let size: CGFloat
    @State private var pulse = false

    var body: some View {
        Text("_")
            .font(AppFont.gridLetter(size * 0.38))
            .foregroundColor(.white.opacity(pulse ? 1 : 0.2))
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
    }
}
