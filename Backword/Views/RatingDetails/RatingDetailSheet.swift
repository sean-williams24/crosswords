import SwiftUI

struct RatingDetailSheet: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var animates = false
    @State private var showHowItWorks = false
    @ScaledMetric private var columnWidth: CGFloat = 60
    @ScaledMetric private var scrollingColumnWidth: CGFloat = 70
    @ScaledMetric private var totalColumnWidth: CGFloat = 30
    @ScaledMetric private var dateColumnWidth: CGFloat = 80
    @ScaledMetric private var dailyColumnWidth: CGFloat = 60

    let rating: OverallRating
    let isPro: Bool
    var onDismiss: (() -> Void)? = nil

    private var tier: RatingTier { rating.tier(isPro: isPro) }
    private var fraction: Double { rating.fraction(isPro: isPro) }

    // Full 14-day calendar, most recent first. Days with no recorded activity default to zero scores.
    private var recentDays: [DailyScore] {
        let fmt = OverallRating.dateFormatter
        let scoreMap = Dictionary(uniqueKeysWithValues: rating.dailyScores.map { ($0.date, $0) })
        return (0..<14).compactMap { offset -> DailyScore? in
            guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            let dateStr = fmt.string(from: date)
            return scoreMap[dateStr] ?? DailyScore(date: dateStr, dailyCrossword: 0, weeklyCrossword: nil, backword: 0)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    tierHero
                        .padding(.horizontal, AppLayout.screenPadding)
                    howItWorksSection
                        .padding(.horizontal, AppLayout.screenPadding)
                    breakdownSection
                }
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color.appBackground)
            .navigationTitle("Your Rating")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { onDismiss?() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.appTextSecondary)
                    }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation(.spring(response: 0.8, dampingFraction: 0.75)) {
                    animates = true
                }
            }
        }
    }

    // MARK: - Tier Hero

    private var tierHero: some View {
        VStack(spacing: 16) {
            // Tier badge
            VStack(spacing: 6) {
                if tier == .virtuoso {
                    Text(tier.displayName.uppercased())
                        .font(AppFont.header(28))
                        .tracking(3)
                        .foregroundStyle(tier.gradient)
                } else {
                    Text(tier.displayName.uppercased())
                        .font(AppFont.header(20))
                        .tracking(3)
                        .foregroundColor(tier.color)
                }

                Text("\(rating.totalPoints(isPro: isPro)) / \(rating.maxPoints(isPro: isPro)) pts · 14 days")
                    .font(AppFont.caption())
                    .foregroundColor(.appTextSecondary)
            }

            // Large progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Bar track (16pt, centered vertically in the ZStack)
                    Capsule()
                        .fill(Color.appSurface)
                        .frame(height: 16)

                    // Gradient fill, masked to filled portion
                    Rectangle()
                        .fill(barGradient)
                        .frame(height: 16)
                        .mask(alignment: .leading) {
                            Capsule()
                                .frame(width: animates ? max(geo.size.width * CGFloat(fraction), 8) : 8)
                        }

                    // Tier threshold markers
                    ForEach(RatingTier.allCases.dropFirst(), id: \.displayName) { t in
                        Capsule()
                            .fill(Color.appBackground.opacity(0.6))
                            .frame(width: 2, height: 16)
                            .offset(x: geo.size.width * CGFloat(t.threshold) - 1)
                    }

                    // Dot (28pt — protrudes above/below the 16pt bar)
                    ZStack {
                        Circle()
                            .fill(tier.color.opacity(0.3))
                            .frame(width: 28, height: 28)
                        Circle()
                            .strokeBorder(tier.color, lineWidth: 2.5)
                            .frame(width: 20, height: 20)
                        Circle()
                            .fill(.white)
                            .frame(width: 10, height: 10)
                    }
                    .shadow(color: tier.color.opacity(0.5), radius: 5, x: 0, y: 0)
                    .offset(x: animates ? max(geo.size.width * CGFloat(fraction) - 14, 0) : 0)
                }
            }
            .frame(height: 28)

            // Tier scale labels
            HStack {
                ForEach(RatingTier.allCases, id: \.displayName) { t in
                    Text(t.displayName)
                        .font(AppFont.clueLabel(9))
                        .foregroundColor(t == tier ? t.color : .appTextSecondary.opacity(0.5))
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                        .minimumScaleFactor(0.2)
                }
            }
        }
        .padding(20)
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius)
                .strokeBorder(tier.color.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Day-by-Day Breakdown

    private var breakdownTitle: some View {
        Text("LAST 14 DAYS")
            .font(AppFont.clueLabel(12))
            .foregroundColor(.appAccent)
            .tracking(2)
            .padding(.leading, AppLayout.screenPadding)
    }

    private var verticalTitle: some View {
        VStack(alignment: .leading) {
            breakdownTitle
            HStack {
                Spacer()
                scrollLabel
            }
        }
    }

    private var horizontalTitle: some View {
        HStack(spacing: 0){
            breakdownTitle
            Spacer()
            scrollLabel
        }
    }

    @ViewBuilder
    private var scrollLabel: some View {
        Text("Scroll")
            .font(AppFont.clueLabel(8))
            .offset(x: 14)
        Image(systemName: "arrow.right")
            .font(AppFont.clueLabel(10))
            .padding(.horizontal, AppLayout.screenPadding)
    }

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if useHorizontalScroll {
                ViewThatFits {
                    horizontalTitle
                    verticalTitle
                }
            } else {
                breakdownTitle
            }

            Group {
                if useHorizontalScroll {
                    ScrollView(.horizontal, showsIndicators: true) {
                        tableViewContent(isScrolling: true)
                            .frame(minWidth: isPro ? 420 : 380)
                    }
                } else {
                    tableViewContent(isScrolling: false)
                }
            }
            .background(Color.appSurface)
        }
    }

    @ViewBuilder
    private func tableViewContent(isScrolling: Bool) -> some View {
        VStack(alignment: .center, spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                Text("Date")
                    .frame(maxWidth: isScrolling ? .none : .infinity, alignment: .leading)
                    .frame(width: isScrolling ? dateColumnWidth : .none, alignment: .leading)

                Text("Daily")
                    .frame(width: isScrolling ? dailyColumnWidth : columnWidth, alignment: .center)

                if isPro {
                    Text("Weekly")
                        .frame(width: isScrolling ? scrollingColumnWidth : columnWidth, alignment: .center)
                }

                Text("Backword")
                    .frame(width: isScrolling ? scrollingColumnWidth : columnWidth, alignment: .center)

                Text("Total")
                    .frame(width: isScrolling ? scrollingColumnWidth : columnWidth, alignment: .center)

            }
            .font(AppFont.clueLabel(10))
            .foregroundColor(.appTextSecondary)
            .tracking(1)
            .padding(.leading, 14)
            .padding(.vertical, 8)
            .padding(.top, 8)

            Divider().background(Color.appGridLine)

            ForEach(Array(recentDays.enumerated()), id: \.element.date) { idx, day in
                breakdownRow(day: day, isScrolling: isScrolling)

                if idx < recentDays.count - 1 {
                    Divider().background(Color.appGridLine.opacity(0.5))
                }
            }
        }
    }

    private var useHorizontalScroll: Bool {
        dynamicTypeSize >= (isPro ? .xLarge : .xxLarge)
    }

    private func breakdownRow(day: DailyScore, isScrolling: Bool) -> some View {
        let weeklyScore = isPro ? (day.weeklyCrossword ?? 0) : 0
        let total = day.dailyCrossword + weeklyScore + day.backword
        let isToday = day.date == Self.localDateFormatter.string(from: Date())
        let isUtcToday = day.date == OverallRating.dateFormatter.string(from: Date())
        let hasWeekly = day.weeklyCrossword != nil

        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 1) {
                Text(formattedDate(day.date))
                    .font(AppFont.body(13))
                    .foregroundColor(isToday ? .appAccent : .appTextPrimary)

                if isToday {
                    Text("TODAY")
                        .font(AppFont.clueLabel(9))
                        .foregroundColor(.appAccent)
                        .tracking(1)
                } else if isUtcToday, let deadline = deadlineTime {
                    Text("Until \(deadline)")
                        .font(AppFont.clueLabel(9))
                        .foregroundColor(.appTextSecondary)
                        .tracking(1)
                }
            }
            .frame(maxWidth: isScrolling ? .none : .infinity, alignment: .leading)
            .frame(width: isScrolling ? dateColumnWidth : .none, alignment: .leading)

            ScoreChipView(score: day.dailyCrossword)
                .frame(width: isScrolling ? dailyColumnWidth : columnWidth, alignment: .center)

            if isPro {
                if hasWeekly {
                    ScoreChipView(score: day.weeklyCrossword ?? 0)
                        .frame(width: isScrolling ? scrollingColumnWidth : columnWidth, alignment: .center)
                } else {
                    Text("—")
                        .font(AppFont.clueLabel(12))
                        .foregroundColor(.appTextSecondary.opacity(0.3))
                        .frame(width: isScrolling ? scrollingColumnWidth : columnWidth, alignment: .center)
                }
            }

            ScoreChipView(score: day.backword)
                .frame(width: isScrolling ? scrollingColumnWidth : columnWidth, alignment: .center)

            Text("\(total)")
                .font(AppFont.clueLabel(13))
                .foregroundColor(total > 0 ? .appTextPrimary : .appTextSecondary.opacity(0.4))
                .frame(width: isScrolling ? scrollingColumnWidth : columnWidth, alignment: .center)
        }
        .padding(.leading, 14)
        .padding(.vertical, 10)
    }

    // MARK: - How It Works

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showHowItWorks.toggle()
                }
            } label: {
                HStack {
                    Text("HOW SCORING WORKS")
                        .font(AppFont.clueLabel(12))
                        .foregroundColor(.appAccent)
                        .tracking(2)
                    Spacer()
                    Image(systemName: showHowItWorks ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.appTextSecondary)
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            if showHowItWorks {
                VStack(alignment: .leading, spacing: 14) {
                    Divider().background(Color.appGridLine)

                    ScoringRuleView.crossword()

                    Text("- 1 point deducted for every 3 hints used")
                        .font(AppFont.caption())
                        .foregroundColor(.appTextSecondary)
                        .padding(.leading, 28)

                    Divider().background(Color.appGridLine.opacity(0.5))

                    ScoringRuleView.backword()

                    Divider().background(Color.appGridLine.opacity(0.5))

                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Image(systemName: "calendar")
                                .font(.system(size: 14))
                                .foregroundColor(.appAccent)
                                .frame(width: 20)
                            Text("Rolling 14-day window")
                                .font(AppFont.clueLabel(13))
                                .foregroundColor(.appTextPrimary)
                        }
                        Text("Your rating reflects only the last 14 days. Skip a day and it scores 0, so play every day to keep your rating up.")
                            .font(AppFont.caption())
                            .foregroundColor(.appTextSecondary)
                            .padding(.leading, 28)
                    }
                    .padding(.bottom, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color.appSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius)
                .strokeBorder(Color.appAccent.opacity(0.15), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    /// Returns the local-time representation of the next UTC midnight (e.g. "1:00 AM" for BST),
    /// or nil if the local and UTC dates are already the same.
    private var deadlineTime: String? {
        guard Self.localDateFormatter.string(from: Date()) != OverallRating.dateFormatter.string(from: Date())
        else { return nil }
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        guard let utcMidnight = utcCal.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: utcMidnight)
    }

    private static let localDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        // No timeZone set — uses the device's local timezone
        return f
    }()

    private var barGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .white, location: 0.0),
                .init(color: Color(white: 0.72), location: 1.0 / 7.0),
                .init(color: RatingTier.novice.color.opacity(0.6), location: 2.0 / 7.0),
                .init(color: RatingTier.scribe.color, location: 3.0 / 7.0),
                .init(color: RatingTier.linguist.color, location: 4.0 / 7.0),
                .init(color: RatingTier.grandmaster.color, location: 5.0 / 7.0),
                .init(color: Color(red: 0.95, green: 0.8, blue: 0.3), location: 6.0 / 7.0),
                .init(color: Color(red: 0.85, green: 0.55, blue: 0.15), location: 1.0)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func formattedDate(_ dateString: String) -> String {
        let inFmt = DateFormatter()
        inFmt.dateFormat = "yyyy-MM-dd"
        inFmt.timeZone = TimeZone(identifier: "UTC")
        guard let date = inFmt.date(from: dateString) else { return dateString }
        let outFmt = DateFormatter()
        outFmt.dateFormat = "EEE, MMM d"
        return outFmt.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    var r = OverallRating()
    let scores = [5, 3, 5, 0, 4, 5, 2, 5, 5, 1, 3, 5, 4, 5]
    for (i, score) in scores.enumerated() {
        let d = Calendar.current.date(byAdding: .day, value: -i, to: Date())!
        let ds = OverallRating.dateFormatter.string(from: d)
        r.upsertDailyCrossword(score: score, date: ds)
        r.upsertBackword(score: max(0, score - 1), date: ds)
    }
    return RatingDetailSheet(rating: r, isPro: false) {}
}
