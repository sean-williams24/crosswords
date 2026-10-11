struct ProAdBenefitsContent {
    let preGameInterstitialsEnabled: Bool

    init(preGameInterstitialsEnabled: Bool = AdConfiguration.preGameInterstitialsEnabled) {
        self.preGameInterstitialsEnabled = preGameInterstitialsEnabled
    }

    var homeTitle: String {
        preGameInterstitialsEnabled ? "Ad-free experience" : "Ad-free hints"
    }

    var settingsFooter: String {
        preGameInterstitialsEnabled
            ? "Subscribe to remove ads, access weekly crossword and all archive games."
            : "Subscribe for ad-free hints, weekly crossword and all archive games."
    }

    var showsAdFreeExperienceBenefit: Bool {
        preGameInterstitialsEnabled
    }
}
