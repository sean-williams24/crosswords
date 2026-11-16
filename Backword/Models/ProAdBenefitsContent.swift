struct ProAdBenefitsContent {
    let adsEnabled: Bool
    let preGameInterstitialsEnabled: Bool

    init(
        adsEnabled: Bool = AdConfiguration.adsEnabled,
        preGameInterstitialsEnabled: Bool = AdConfiguration.preGameInterstitialsEnabled
    ) {
        self.adsEnabled = adsEnabled
        self.preGameInterstitialsEnabled = preGameInterstitialsEnabled
    }

    var homeTitle: String {
        adsEnabled ? (preGameInterstitialsEnabled ? "Ad-free experience" : "Ad-free hints") : "Archive access"
    }

    var settingsFooter: String {
        guard adsEnabled else { return "Subscribe for weekly crossword and all archive games." }
        return preGameInterstitialsEnabled
            ? "Subscribe to remove ads, access weekly crossword and all archive games."
            : "Subscribe for ad-free hints, weekly crossword and all archive games."
    }

    var showsAdFreeHintsBenefit: Bool { adsEnabled }

    var showsAdFreeExperienceBenefit: Bool {
        adsEnabled && preGameInterstitialsEnabled
    }
}
