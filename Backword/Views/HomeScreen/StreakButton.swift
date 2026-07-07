import SwiftUI

struct StreakButton: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showPopup = false

    let streak: Int

    var body: some View {
        if streak > 0 {
            Button {
                showPopup.toggle()
                if showPopup {
                    Task {
                        try? await Task.sleep(nanoseconds: 4_000_000_000)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showPopup = false
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text("\(streak)")
                        .font(AppFont.clueLabel(12))
                        .foregroundColor(.appTextPrimary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.appSurface.opacity(0.5))
                .cornerRadius(AppLayout.cardCornerRadius)
            }
            .buttonStyle(.plain)
            .overlay(alignment: .topTrailing) {
                if showPopup {
                    Text("\(streak)-day streak")
                        .fixedSize()
                        .font(AppFont.clueLabel(12))
                        .foregroundColor(.appTextPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.appSurface)
                        .cornerRadius(10)
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 2)
                        .offset(y: dynamicTypeSize >= .accessibility1 ? -60 : 0)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: showPopup)
        }
    }
}
