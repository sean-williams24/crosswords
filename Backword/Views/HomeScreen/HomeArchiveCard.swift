import SwiftUI

struct HomeArchiveCard: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.homeCardFillsProposedHeight) private var fillsProposedHeight

    let isProUser: Bool
    let openArchive: () -> Void

    var body: some View {
        Button(action: openArchive) {
            VStack(spacing: AppLayout.homeArchiveContentSpacing) {
                HStack(spacing: AppLayout.homeArchiveContentSpacing) {
                    Image(systemName: "archivebox")
                        .foregroundStyle(Color.appAccent)
                    Text("ARCHIVE")
                        .foregroundStyle(Color.appTextPrimary)
                }
                .font(AppFont.clueLabel(AppLayout.homeArchiveTitleSize))

                Text("Unlock the full archive for all five games")
                    .font(AppFont.caption())
                    .foregroundStyle(Color.appTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.center)
            .padding(AppLayout.screenPadding)
            .frame(
                maxWidth: .infinity,
                minHeight: AppLayout(sizeClass: sizeClass).cardHeight,
                maxHeight: fillsProposedHeight ? .infinity : nil
            )
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius)
                    .strokeBorder(Color.homeArchiveBorder, lineWidth: AppLayout.homeArchiveBorderWidth)
            }
            .contentShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(HomeTabBarItemContent.archive(isProUser: isProUser).accessibilityLabel)
        .accessibilityHint("Unlock the full archive for all five games")
    }
}
