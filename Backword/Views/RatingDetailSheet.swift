import SwiftUI

struct RatingDetailSheet: View {
    let rating: OverallRating
    let isPro: Bool
    var onDismiss: (() -> Void)? = nil

    @State private var animates = false
    @State private var showHowItWorks = false

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
            ZStack {
                LinearGradient(
                    colors: [tier.color.opacity(0.12), Color.appBackground],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        tierHero
                        breakdownSection
                        howItWorksSection
                    }
                    .padding(.horizontal, AppLayout.screenPadding)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
            }
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

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LAST 14 DAYS")
                .font(AppFont.clueLabel(12))
                .foregroundColor(.appAccent)
                .tracking(2)

            VStack(spacing: 0) {
                    // Header row
                    HStack(spacing: 0) {
                        Text("Date")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Daily")
                            .frame(width: 44, alignment: .center)
                        if isPro {
                            Text("Weekly")
                                .frame(width: 52, alignment: .center)
                        }
                        Text("Backword")
                            .frame(width: 66, alignment: .center)
                        Text("Total")
                            .frame(width: 44, alignment: .trailing)
                    }
                    .font(AppFont.clueLabel(10))
                    .foregroundColor(.appTextSecondary)
                    .tracking(1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)

                    Divider().background(Color.appGridLine)

                    ForEach(Array(recentDays.enumerated()), id: \.element.date) { idx, day in
                        breakdownRow(day: day)

                        if idx < recentDays.count - 1 {
                            Divider().background(Color.appGridLine.opacity(0.5))
                        }
                    }
                }
                .background(Color.appSurface)
                .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius)
                        .strokeBorder(Color.appAccent.opacity(0.15), lineWidth: 1)
                )
        }
    }

    private func breakdownRow(day: DailyScore) -> some View {
        let weeklyScore = isPro ? (day.weeklyCrossword ?? 0) : 0
        let total = day.dailyCrossword + weeklyScore + day.backword
        let isToday = day.date == OverallRating.dateFormatter.string(from: Date())
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
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            scoreChip(day.dailyCrossword)
                .frame(width: 44, alignment: .center)

            if isPro {
                if hasWeekly {
                    scoreChip(day.weeklyCrossword ?? 0)
                        .frame(width: 52, alignment: .center)
                } else {
                    Text("—")
                        .font(AppFont.clueLabel(12))
                        .foregroundColor(.appTextSecondary.opacity(0.3))
                        .frame(width: 52, alignment: .center)
                }
            }

            scoreChip(day.backword)
                .frame(width: 66, alignment: .center)

            Text("\(total)")
                .font(AppFont.clueLabel(13))
                .foregroundColor(total > 0 ? .appTextPrimary : .appTextSecondary.opacity(0.4))
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func scoreChip(_ score: Int) -> some View {
        let color: Color = score == 5 ? .appCorrect : score > 0 ? .appAccent : .appTextSecondary.opacity(0.25)
        return Text("\(score)")
            .font(AppFont.clueLabel(12))
            .foregroundColor(score > 0 ? .white : .appTextSecondary.opacity(0.4))
            .frame(width: 24, height: 24)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 6))
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

                    scoringRule(
                        icon: "square.grid.3x3.fill",
                        title: "Daily & Weekly Crossword",
                        rows: [
                            ("100% complete", "5 pts"),
                            ("75–99% complete", "4 pts"),
                            ("50–74% complete", "3 pts"),
                            ("25–49% complete", "2 pts"),
                            ("1–24% complete", "1 pt"),
                            ("Not started", "0 pts"),
                        ]
                    )

                    Divider().background(Color.appGridLine.opacity(0.5))

                    scoringRule(
                        icon: "textformat.abc",
                        title: "Backword",
                        rows: [
                            ("Win in 1 guess", "5 pts"),
                            ("Win in 2 guesses", "4 pts"),
                            ("Win in 3 guesses", "3 pts"),
                            ("Win in 4 guesses", "2 pts"),
                            ("Win in 5 guesses", "1 pt"),
                            ("Loss or missed", "0 pts"),
                        ]
                    )

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
                        Text("Your rating reflects only the last 14 days. Skip a day and it scores 0, so play every day to keep your rating high!")
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

    private func scoringRule(icon: String, title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.appAccent)
                    .frame(width: 20)
                Text(title)
                    .font(AppFont.clueLabel(13))
                    .foregroundColor(.appTextPrimary)
            }
            VStack(spacing: 4) {
                ForEach(rows, id: \.0) { label, pts in
                    HStack {
                        Text(label)
                            .font(AppFont.caption())
                            .foregroundColor(.appTextSecondary)
                        Spacer()
                        Text(pts)
                            .font(AppFont.clueLabel(11))
                            .foregroundColor(.appAccent)
                    }
                    .padding(.leading, 28)
                }
            }
        }
    }

    // MARK: - Helpers

    private var barGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .white, location: 0.0),
                .init(color: Color(white: 0.72), location: 1.0 / 7.0),
                .init(color: RatingTier.dabbler.color.opacity(0.6), location: 2.0 / 7.0),
                .init(color: RatingTier.penman.color, location: 3.0 / 7.0),
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
