import SwiftUI

struct ArchiveMonthGrid: View {
    let months: [ArchiveMonth]
    let type: ArchiveGameType
    let expandedMonth: ArchiveMonth?
    let loadingMonths: Set<ArchiveMonthKey>
    let unavailableMonths: Set<ArchiveMonthKey>
    let onTap: (ArchiveMonth) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(months) { month in
                Button {
                    onTap(month)
                } label: {
                    VStack(spacing: 4) {
                        if loadingMonths.contains(ArchiveMonthKey(type: type, month: month)) {
                            ProgressView()
                                .tint(.appAccent)
                                .scaleEffect(0.75)
                                .frame(height: 18)
                        } else {
                            Text(month.shortDisplayName)
                                .font(AppFont.clueLabel(13))
                                .foregroundColor(expandedMonth == month ? .appTextPrimary : .appTextSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                        }

                        if unavailableMonths.contains(ArchiveMonthKey(type: type, month: month)) {
                            Text("Unavailable")
                                .font(AppFont.caption(10))
                                .foregroundColor(.appTextSecondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(expandedMonth == month ? Color.appAccent.opacity(0.16) : Color.appSurface)
                    .cornerRadius(AppLayout.cardCornerRadius)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
