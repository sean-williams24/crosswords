import SwiftUI

struct HomeGameCardContent<Identity: View, Details: View, Accessory: View, Header: View>: View {
    let minimumHeight: CGFloat
    var identityPosition: HomeGameCardLayout.IdentityPosition = .center
    var spacing: CGFloat = AnagramHomeCardLayout.contentSpacing
    @ViewBuilder var identity: () -> Identity
    @ViewBuilder var details: () -> Details
    @ViewBuilder var accessory: () -> Accessory
    @ViewBuilder var header: () -> Header

    var body: some View {
        HomeGameCardLayout(
            minimumHeight: minimumHeight - 2 * AnagramHomeCardLayout.verticalPadding,
            spacing: spacing,
            identityPosition: identityPosition
        ) {
            header()
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .layoutValue(key: HomeGameCardLayout.RegionKey.self, value: .header)

            identity()
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .layoutValue(key: HomeGameCardLayout.RegionKey.self, value: .identity)

            accessory()
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .layoutValue(key: HomeGameCardLayout.RegionKey.self, value: .accessory)

            details()
                .frame(maxWidth: .infinity, alignment: .center)
                .layoutValue(key: HomeGameCardLayout.RegionKey.self, value: .details)
        }
        .padding(.horizontal, AnagramHomeCardLayout.horizontalPadding)
        .padding(.vertical, AnagramHomeCardLayout.verticalPadding)
        .frame(maxWidth: .infinity, minHeight: minimumHeight)
    }
}

extension HomeGameCardContent where Header == EmptyView {
    init(
        minimumHeight: CGFloat,
        identityPosition: HomeGameCardLayout.IdentityPosition = .center,
        spacing: CGFloat = AnagramHomeCardLayout.contentSpacing,
        @ViewBuilder identity: @escaping () -> Identity,
        @ViewBuilder details: @escaping () -> Details,
        @ViewBuilder accessory: @escaping () -> Accessory
    ) {
        self.minimumHeight = minimumHeight
        self.spacing = spacing
        self.identityPosition = identityPosition
        self.identity = identity
        self.details = details
        self.accessory = accessory
        self.header = { EmptyView() }
    }
}

extension HomeGameCardContent where Accessory == EmptyView {
    init(
        minimumHeight: CGFloat,
        spacing: CGFloat = AnagramHomeCardLayout.contentSpacing,
        @ViewBuilder identity: @escaping () -> Identity,
        @ViewBuilder details: @escaping () -> Details,
        @ViewBuilder header: @escaping () -> Header
    ) {
        self.minimumHeight = minimumHeight
        self.spacing = spacing
        self.identity = identity
        self.details = details
        self.accessory = { EmptyView() }
        self.header = header
    }
}

extension HomeGameCardContent where Accessory == EmptyView, Header == EmptyView {
    init(
        minimumHeight: CGFloat,
        spacing: CGFloat = AnagramHomeCardLayout.contentSpacing,
        @ViewBuilder identity: @escaping () -> Identity,
        @ViewBuilder details: @escaping () -> Details
    ) {
        self.minimumHeight = minimumHeight
        self.spacing = spacing
        self.identity = identity
        self.details = details
        self.accessory = { EmptyView() }
        self.header = { EmptyView() }
    }
}
