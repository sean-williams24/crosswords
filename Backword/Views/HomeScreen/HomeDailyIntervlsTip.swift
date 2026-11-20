import SwiftUI

struct HomeDailyIntervlsTip: View {
    let openGuide: () -> Void
    let dismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: AppLayout.dailyIntervlsTipSpacing) {
            VStack(alignment: .leading, spacing: AppLayout.homeDailySummaryLineSpacing) {
                Text("Your Daily Intervls guide")
                    .font(AppFont.header(16))
                    .foregroundStyle(Color.appTextHeading)
                Text("See how to finish your daily games and build your rating.")
                    .font(AppFont.body())
                    .foregroundStyle(Color.appTextPrimary)
                Button(action: openGuide) {
                    Text("View guide")
                        .font(AppFont.header(16))
                        .frame(minHeight: AppLayout.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .tint(.appAccent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.appTextSecondary)
                    .frame(width: AppLayout.minimumTouchTarget, height: AppLayout.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss Daily Intervls tip")
        }
        .padding(AppLayout.dailyIntervlsTipPadding)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
    }
}

#if DEBUG
#Preview("Daily Intervls · Returning player") {
    @Previewable @State var showsTip = true
    @Previewable @State var showsGuide = false

    VStack(spacing: HomeGamesLayout.spacing) {
        RatingBarView(
            rating: OverallRating(),
            isPro: false,
            dailyChallenge: DailyChallengeSnapshot(date: ContentReleaseCalendar().dailyDateString),
            onOpenDetails: {}
        )
        if showsTip {
            HomeDailyIntervlsTip {
                showsTip = false
                showsGuide = true
            } dismiss: {
                showsTip = false
            }
        }
    }
    .padding(AppLayout.screenPadding)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(AppBackgroundGradient())
    .allowsHitTesting(!showsGuide)
    .accessibilityHidden(showsGuide)
    .overlay {
        if showsGuide {
            DailyIntervlsGuideView(dismiss: { showsGuide = false })
        }
    }
}
#endif
