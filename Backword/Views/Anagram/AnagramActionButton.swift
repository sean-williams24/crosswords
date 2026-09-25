import SwiftUI

struct AnagramActionButton: View {
    let title: String
    var prominent = false
    var enabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppFont.body(16))
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(prominent ? Color.anagramOnOrange : Color.anagramOrange)
                .background(prominent ? Color.anagramOrange : Color.anagramSurface)
                .overlay { Rectangle().strokeBorder(Color.anagramOrange, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}
