//  BackwordArchiveRow.swift

import SwiftUI

struct BackwordArchiveRow: View {
    @EnvironmentObject var storeService: StoreService
    @EnvironmentObject var adService: AdService
    @State private var showBackword = false
    @State private var progress: BackwordProgress?

    let word: BackwordWord

    var body: some View {
        Button {
            showBackword = true
        } label: {
            ViewThatFits {
                HStack(spacing: 16) {
                    DateSection(date: word.date)
                    Spacer()
                    StatusLabelView(status: .status(for: progress, puzzleDate: word.date))
                }
                VStack(alignment: .leading) {
                    DateSection(date: word.date)
                    StatusLabelView(status: .status(for: progress, puzzleDate: word.date))
                }
            }
            .frame(minHeight: 50)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.appSurface)
            .cornerRadius(AppLayout.cardCornerRadius)
        }
        .buttonStyle(.plain)
        .navigationDestination(isPresented: $showBackword) {
            BackwordView(word: word)
                .environmentObject(storeService)
                .environmentObject(adService)
        }
        .onAppear(perform: refreshProgress)
        .onChange(of: showBackword) { _, isPresented in
            guard !isPresented else { return }
            refreshProgress()
        }
        .onReceive(NotificationCenter.default.publisher(for: .backwordProgressDidChange)) { notification in
            guard let changedDate = notification.userInfo?[BackwordProgress.changedDateUserInfoKey] as? String,
                  changedDate == word.date else { return }
            refreshProgress()
        }
    }

    private func refreshProgress() {
        progress = BackwordProgress.load(date: word.date)
    }
}

// MARK: - Extracted Subviews

private struct DateSection: View {
    let date: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(formattedDate(date))
                .font(AppFont.body())
                .foregroundColor(.appTextPrimary)

            if isToday(date) {
                Text("TODAY")
                    .font(AppFont.clueLabel(10))
                    .foregroundColor(.appAccent)
                    .tracking(1)
            }
        }
    }
}

private func formattedDate(_ dateString: String) -> String {
    let inputFmt = DateFormatter()
    inputFmt.dateFormat = "yyyy-MM-dd"
    guard let date = inputFmt.date(from: dateString) else { return dateString }

    let outputFmt = DateFormatter()
    outputFmt.dateFormat = "EEEE, MMM d"
    return outputFmt.string(from: date)
}

private func isToday(_ dateString: String) -> Bool {
    dateString == ContentReleaseCalendar().dailyDateString
}


#Preview {
    BackwordArchiveRow(
        word: .init(
            id: "",
            date: "Wednesday, May 20",
            word: "CASTLE",
            clue: "CHESS"
        )
    )
    .environmentObject(StoreService())
    .environmentObject(AdService())
}
