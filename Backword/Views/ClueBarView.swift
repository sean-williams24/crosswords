import SwiftUI

struct ClueBarView: View {
    @ObservedObject var viewModel: GameViewModel

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: 12) {
            // Direction + number label
            if let clue = viewModel.activeClue {
                Text("\(clue.number)\(clue.direction == .across ? "A" : "D")")
                    .font(AppFont.clueLabel())
                    .foregroundColor(.appAccent)
                    .frame(minWidth: 30)

                Text(viewModel.currentClueText)
                    .font(AppFont.clueText())
                    .foregroundColor(.appTextPrimary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(clue.id) // force transition on clue change
                    .transition(.asymmetric(
                        insertion: .move(edge: dragOffset > 0 ? .leading : .trailing).combined(with: .opacity),
                        removal: .move(edge: dragOffset > 0 ? .trailing : .leading).combined(with: .opacity)
                    ))
            } else {
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.appSurface)
        .cornerRadius(AppLayout.cardCornerRadius)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 30, coordinateSpace: .local)
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        if value.translation.width > 50 {
                            viewModel.previousClue()
                        } else if value.translation.width < -50 {
                            viewModel.nextClue()
                        }
                    }
                    dragOffset = 0
                }
        )
        .onTapGesture {
            viewModel.toggleDirection()
        }
    }
}
