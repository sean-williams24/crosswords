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
                    }
                }
                .listStyle(.plain)
                .onAppear {
                    if let active = viewModel.activeClue {
                        proxy.scrollTo(active.id, anchor: .center)
                    }
                }
            }
            .navigationTitle("Clues")
            .navigationBarTitleDisplayMode(.inline)
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
        .presentationDetents([.medium, .large])
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
