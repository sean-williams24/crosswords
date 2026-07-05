import SwiftUI

struct AdExplainerView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Binding var doNotShowAgain: Bool
    let gameName: String
    let close: () -> Void
    let play: () -> Void
    let showAdFreeExperience: () -> Void

    var body: some View {
        ZStack {
            AppBackgroundGradient()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button(action: close) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.appTextSecondary)
                    }
                    .accessibilityLabel("Close")
                }
                .padding(.horizontal, AppLayout.screenPadding)
                .padding(.top, 18)

                ZStack(alignment: .bottom) {
                    ScrollView {
                        scrollContent
                            .padding(.horizontal, AppLayout.screenPadding)
                            .padding(.top, 24)
                            .padding(.bottom, bottomActionPadding)
                            .frame(maxWidth: 520)
                            .frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.hidden)

                    bottomActionPanel
                }
            }
        }
    }

    private var iconSize: CGFloat {
        dynamicTypeSize >= .accessibility1 ? 34 : 48
    }

    private var titleFontSize: CGFloat {
        dynamicTypeSize >= .accessibility1 ? 16 : 18
    }

    private var shouldStackToggle: Bool {
        dynamicTypeSize >= .accessibility1
    }

    private var bottomControlHeight: CGFloat {
        dynamicTypeSize >= .accessibility1 ? 72 : 52
    }

    private var bottomActionPadding: CGFloat {
        dynamicTypeSize >= .accessibility1 ? 390 : 300
    }

    private var scrollContent: some View {
        VStack(spacing: 22) {
            Image(systemName: "play.rectangle.on.rectangle")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(.appAccent)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                explainerText(
                    "A quick note before you play...",
                    font: AppFont.header(titleFontSize),
                    color: .appTextHeading
                )

                explainerText(
                    "On the free version of Backword, we may show a full-screen advert before the \(gameName). The advert usually has a short progress bar or timer, and the close button appears when it finishes.",
                    font: AppFont.body(15),
                    color: .appTextPrimary
                )
                .lineSpacing(4)

                explainerText(
                    "We only show one advert per day for each game.",
                    font: AppFont.body(15),
                    color: .appTextPrimary
                )
            }
        }
    }

    private var bottomActionPanel: some View {
        VStack(spacing: 14) {
            AdFreeExperienceButton(height: bottomControlHeight, action: showAdFreeExperience)
            toggleRow
            playButton
        }
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.top, 14)
        .padding(.bottom, 18)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
        .background(
            Color.appCrosswordBackground/*opacity(0.8)*/
                .background(.ultraThinMaterial)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func explainerText(_ text: String, font: Font, color: Color) -> some View {
        Text(text)
            .font(font)
            .foregroundColor(color)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var playButton: some View {
        Button(action: play) {
            Text("Let's play")
                .font(AppFont.header(18))
                .foregroundColor(.appBackground)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: bottomControlHeight)
                .background(Color.appAccent)
                .dynamicTypeSize(...DynamicTypeSize.accessibility1)
                .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
        }
    }

    @ViewBuilder
    private var toggleRow: some View {
//        if shouldStackToggle {
//            VStack(alignment: .leading, spacing: 16) {
//                toggleLabel
//                HStack {
//                    Spacer()
//                    Toggle("", isOn: $doNotShowAgain)
//                        .labelsHidden()
//                        .tint(.appAccent)
//                }
//            }
//            .frame(maxWidth: .infinity, alignment: .leading)
//            .padding(.horizontal, 18)
//            .frame(height: bottomControlHeight)
//            .background(Color.appSurface)
//            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
//            .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
//        } else {
            Toggle(isOn: $doNotShowAgain) {
                toggleLabel
            }
            .tint(.appAccent)
            .padding(.horizontal, 18)
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .frame(height: bottomControlHeight)
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius))
//        }
    }

    private var toggleLabel: some View {
        Text("I get it, don't show this again")
            .font(AppFont.caption(14))
            .foregroundColor(.appTextPrimary)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    AdExplainerView(
        doNotShowAgain: .constant(false),
        gameName: "Crossword",
        close: {},
        play: {},
        showAdFreeExperience: {}
    )
}
