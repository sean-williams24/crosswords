//  BackwordArchiveRow.swift

import SwiftUI

struct BackwordArchiveRow: View {
    @EnvironmentObject var storeService: StoreService
    @EnvironmentObject var adService: AdService
    @State private var showBackword = false

    let word: BackwordWord

    var body: some View {
        let progress = BackwordProgress.load(date: word.date)
        let content = BackwordArchiveRowContent(word: word)

        Button {
            showBackword = true
        } label: {
            ViewThatFits {
                HStack(spacing: 16) {
                    ArchiveDetails(content: content)
                    Spacer()
                    StatusLabelView(status: .status(for: progress))
                }
                VStack(alignment: .leading) {
                    ArchiveDetails(content: content)
                    StatusLabelView(status: .status(for: progress))
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
    }
}

// MARK: - Extracted Subviews

private struct ArchiveDetails: View {
    let content: BackwordArchiveRowContent

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(content.clue.uppercased())
                .font(AppFont.clueLabel(12))
                .foregroundColor(.appAccent)

            Text(content.formattedDate)
                .font(AppFont.body())
                .foregroundColor(.appTextPrimary)

            if content.isToday {
                Text("TODAY")
                    .font(AppFont.clueLabel(10))
                    .foregroundColor(.appAccent)
                    .tracking(1)
            }
        }
    }
}

struct BackwordArchiveRowContent: Equatable {
    let clue: String
    let formattedDate: String
    let isToday: Bool

    init(word: BackwordWord, today: String = ContentReleaseCalendar().dailyDateString) {
        clue = word.clue
        formattedDate = Self.formatDate(word.date)
        isToday = word.date == today
    }

    private static func formatDate(_ dateString: String) -> String {
        let inputFmt = DateFormatter()
        inputFmt.dateFormat = "yyyy-MM-dd"
        guard let date = inputFmt.date(from: dateString) else { return dateString }

        let outputFmt = DateFormatter()
        outputFmt.dateFormat = "EEEE, MMM d"
        return outputFmt.string(from: date)
    }

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
