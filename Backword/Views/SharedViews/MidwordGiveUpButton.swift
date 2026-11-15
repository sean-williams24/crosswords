import SwiftUI

struct MidwordGiveUpButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Give up")
                .font(AppFont.body(16))
                .foregroundStyle(Color.midwordOnAccent)
                .padding(.horizontal, AppLayout.keyboardActionHorizontalPadding)
                .frame(minHeight: AppLayout.minimumTouchTarget)
                .background(
                    Color.midwordAccent,
                    in: RoundedRectangle(cornerRadius: AppLayout.keyboardKeyCornerRadius)
                )
        }
        .buttonStyle(.plain)
    }
}
