import SwiftUI

struct GameSubmitButton: View {
    var backgroundColor: Color = .appAccent
    var textColor: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Submit")
                .font(AppFont.clueLabel(15))
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(backgroundColor)
                .cornerRadius(AppLayout.cardCornerRadius)
        }
    }
}
