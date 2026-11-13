import SwiftUI

struct TimedGameStartCard: View {
    let heading: String
    let explanation: String
    let detail: String
    let foreground: Color
    let accent: Color
    let surface: Color
    let onAccent: Color
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(heading)
                .font(AppFont.header(24))
                .dynamicTypeSize(...DynamicTypeSize.xLarge)
            Text(explanation)
                .font(AppFont.body())
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            Text(detail)
                .font(AppFont.caption())
                .foregroundStyle(accent)
                .dynamicTypeSize(...DynamicTypeSize.large)
            Button(action: onStart) {
                Text("Start")
                    .font(AppFont.body(16))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .foregroundStyle(onAccent)
                    .background(accent)
                    .overlay { Rectangle().strokeBorder(accent, lineWidth: 1) }
            }
            .buttonStyle(.plain)
            .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(AppLayout.screenPadding)
        .background(surface)
    }
}
