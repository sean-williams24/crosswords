import SwiftUI

struct ClueListView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var viewModel: GameViewModel
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric private var clueFrame: CGFloat = 24

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    Section {
                        ForEach(Array(viewModel.puzzle.acrossClues.enumerated()), id: \.element.id) { index, clue in
                            clueRow(clue, isFirst: index == 0, isLast: index == viewModel.puzzle.acrossClues.count - 1)
                        }
                    } header: {
                        Text("ACROSS")
                            .font(AppFont.clueLabel(14))
                            .foregroundColor(.appAccent)
                            .tracking(2)
                            .textCase(nil)
                            .listRowInsets(EdgeInsets())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.appBackground)
                    }

                    Section {
                        ForEach(Array(viewModel.puzzle.downClues.enumerated()), id: \.element.id) { index, clue in
                            clueRow(clue, isFirst: index == 0, isLast: index == viewModel.puzzle.downClues.count - 1)
                        }
                    } header: {
                        Text("DOWN")
                            .font(AppFont.clueLabel(14))
                            .foregroundColor(.appAccent)
                            .tracking(2)
                            .textCase(nil)
                            .listRowInsets(EdgeInsets())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.appBackground)
                    }
                }
                .background(Color.appBackground)
                .listStyle(.plain)
                .onAppear {
                    if let active = viewModel.activeClue {
                        proxy.scrollTo(active.id, anchor: .center)
                    }
                }
            }
            .navigationTitle("Clues")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.appTextSecondary)
                    }
                }
            }
        }
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func clueRow(_ clue: Clue, isFirst: Bool = false, isLast: Bool = false) -> some View {
        let isCompleted = viewModel.progress.completedClueIds.contains(clue.id)
        let isActive = viewModel.activeClue?.id == clue.id

        Button {
            viewModel.navigateToClue(clue)
            dismiss()
        } label: {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    clueNumber(clue: clue, isActive: isActive)
                    clueText(clue: clue, isCompleted: isCompleted)
                    HStack {
                        Spacer()
                        clueLength(clue: clue, isCompleted: isCompleted)
                    }
                }
            } else {
                HStack(alignment: .top, spacing: 10) {
                    clueNumber(clue: clue, isActive: isActive)
                    clueText(clue: clue, isCompleted: isCompleted)
                    clueLength(clue: clue, isCompleted: isCompleted)
                }
                .padding(.vertical, 4)
            }
        }
        .id(clue.id)
        .listRowSeparator(isFirst ? .hidden : .visible, edges: .top)
        .listRowSeparator(isLast ? .hidden : .visible, edges: .bottom)
        .listRowBackground(isActive ? Color.appAccent.opacity(0.08) : Color.appSurface)
    }

    private func clueNumber(clue: Clue, isActive: Bool) -> some View {
        Text("\(clue.number)")
            .font(AppFont.clueLabel(14))
            .foregroundColor(isActive ? .appAccent : .appTextSecondary)
            .frame(width: clueFrame, alignment: .leading)
    }

    private func clueText(clue: Clue, isCompleted: Bool) -> some View {
        Text(clue.text)
            .font(AppFont.clueText())
            .foregroundColor(isCompleted ? .appTextSecondary : .appTextPrimary)
            .strikethrough(isCompleted)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func clueLength(clue: Clue, isCompleted: Bool) -> some View {
        Text("(\(clue.length))")
            .font(AppFont.caption(13))
            .foregroundColor(.appTextSecondary)
            .foregroundColor(isCompleted ? .appCorrect : .appTextPrimary)
    }
}

#Preview {
    ClueListView(viewModel: GameViewModel(puzzle: .sample))
}
