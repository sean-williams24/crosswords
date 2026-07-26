import SwiftUI

struct BackwordModeToggle: View {
    @Binding var mode: BackwordMode

    var body: some View {
        Toggle(isOn: isEasyMode) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.title(isEnabled: mode == .easy))
                    .font(AppFont.body(15))
                    .foregroundColor(.appTextPrimary)

                Text("Reveal another letter after every wrong guess")
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
        "Easy Mode - \(isEnabled ? "on" : "off")"
    }

    private var isEasyMode: Binding<Bool> {
        Binding(
            get: { mode == .easy },
            set: { mode = $0 ? .easy : .normal }
        )
    }
}

#Preview {
    BackwordModeToggle(mode: .constant(.normal))
        .padding()
        .background(Color.appBackground)
}
