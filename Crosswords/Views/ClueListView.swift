import SwiftUI

struct ClueListView: View {
    @ObservedObject var viewModel: GameViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                    Section {
                        ForEach(viewModel.puzzle.acrossClues) { clue in
                            clueRow(clue)
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
                        ForEach(viewModel.puzzle.downClues) { clue in
                            clueRow(clue)
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
                .listStyle(.plain)
                .environment(\.defaultMinListHeaderHeight, 0)
                .padding(.top, -22)
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
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func clueRow(_ clue: Clue) -> some View {
        let isCompleted = viewModel.progress.completedClueIds.contains(clue.id)
        let isActive = viewModel.activeClue?.id == clue.id

        Button {
            viewModel.navigateToClue(clue)
            dismiss()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Text("\(clue.number)")
                    .font(AppFont.clueLabel(14))
                    .foregroundColor(isActive ? .appAccent : .appTextSecondary)
                    .frame(width: 24, alignment: .trailing)

                Text(clue.text)
                    .font(AppFont.clueText())
                    .foregroundColor(isCompleted ? .appTextSecondary : .appTextPrimary)
                    .strikethrough(isCompleted)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.appCorrect)
                        .font(.system(size: 14))
                }
            }
            .padding(.vertical, 4)
        }
        .id(clue.id)
        .listRowBackground(isActive ? Color.appAccent.opacity(0.08) : Color.clear)
    }
}

#Preview {
    ClueListView(viewModel: GameViewModel(puzzle: .sample))
}
