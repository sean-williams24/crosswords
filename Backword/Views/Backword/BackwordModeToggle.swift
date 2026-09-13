import SwiftUI

struct BackwordModeToggle: View {
    @Binding var mode: BackwordMode

    var body: some View {
        Toggle(isOn: isHardMode) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.title(isEnabled: Self.isHardMode(mode)))
                    .font(AppFont.body(15))
                    .foregroundColor(.appTextPrimary)

                Text("Reveal fewer letters after wrong guesses when enabled")
                    .font(AppFont.caption())
                    .foregroundColor(.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(.appAccent)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }

    static func title(isEnabled: Bool) -> String {
        "Hard Mode - \(isEnabled ? "On" : "Off")"
    }

    static func isHardMode(_ mode: BackwordMode) -> Bool {
        mode == .normal
    }

    static func mode(isHardMode: Bool) -> BackwordMode {
        isHardMode ? .normal : .easy
    }

    private var isHardMode: Binding<Bool> {
        Binding(
            get: { Self.isHardMode(mode) },
            set: { mode = Self.mode(isHardMode: $0) }
        )
    }
}

#Preview {
    BackwordModeToggle(mode: .constant(.normal))
        .padding()
        .background(Color.appBackground)
}
