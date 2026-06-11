import SwiftUI

struct ClueBarView: View {
    @Environment(\.horizontalSizeClass) var sizeClass
    @ObservedObject var viewModel: GameViewModel

    @State private var dragOffset: CGFloat = 0

    private var isIpad: Bool {
        sizeClass == .regular
    }

    var body: some View {
        HStack(spacing: 12) {
            // Direction + number label
            if let clue = viewModel.activeClue {
                Text("\(clue.number)\(clue.direction == .across ? "A" : "D")")
                    .font(AppFont.clueLabel(isIpad ? 16 : 12))
                    .foregroundColor(.appAccent)
                    .frame(minWidth: 30)
                    .contentTransition(.opacity)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.activeClue)
                Text(viewModel.currentClueText)
                    .font(AppFont.clueText(isIpad ? 20 : 15))
                    .foregroundColor(.appTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentTransition(.opacity)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.activeClue)
                    .id(viewModel.showHint)
                    .transition(.slide)
                    .animation(.easeInOut(duration: 0.4), value: viewModel.showHint)
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
