import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @EnvironmentObject var storeService: StoreService
    @EnvironmentObject var adService: AdService
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appColorScheme") private var appColorScheme: Int = 2
    @State private var isShowingMailComposer = false
    @State private var isFeedbackRowPressed = false
    @State private var isAdPrivacyChoicesRowPressed = false

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Appearance")) {
                    Picker("Theme", selection: $appColorScheme) {
                        Text("Light").tag(1)
                        Text("Dark").tag(2)
                        Text("System").tag(3)
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    correctHighlightRow
                } header: {
                    Text("CROSSWORDS")
                        .font(AppFont.clueLabel(12))
                        .foregroundColor(.appAccent)
                        .tracking(2)
                        .textCase(nil)
                } footer: {
                    Text("When enabled, correctly completed answers are highlighted green and locked. Disable for a harder experience.")
                        .font(AppFont.caption())
                        .foregroundColor(.appTextSecondary)
                }

                Section {
                    sendFeedbackRow
                } header: {
                    Text("SUPPORT")
                        .font(AppFont.clueLabel(12))
                        .foregroundColor(.appAccent)
                        .tracking(2)
                        .textCase(nil)
                }

                Section {
                    if Self.showsAdPrivacyChoicesRow(isPrivacyOptionsRequired: adService.isPrivacyOptionsRequired) {
                        adPrivacyChoicesRow
                    }

                    ForEach(LegalLink.all) { link in
                        legalLinkRow(link)
                    }
                } header: {
                    Text("LEGAL")
                        .font(AppFont.clueLabel(12))
                        .foregroundColor(.appAccent)
                        .tracking(2)
                        .textCase(nil)
                }

//                Section {
//                    letterFeedbackRow
//                } header: {
//                    Text("BACKWORD")
//                        .font(AppFont.clueLabel(12))
//                        .foregroundColor(.appAccent)
//                        .tracking(2)
//                        .textCase(nil)
//                } footer: {
//                    Text("When enabled, letters in your past guesses that appear anywhere in the target word are highlighted.")
//                        .font(AppFont.caption())
//                        .foregroundColor(.appTextSecondary)
//                }
            }
            .safeAreaInset(edge: .bottom) {
                appVersionFooter
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(selectedScheme)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .onAppear {
                adService.refreshPrivacyOptionsRequirement()
            }
            .sheet(isPresented: $isShowingMailComposer) {
                MailComposerView(
                    content: .current,
                    isPresented: $isShowingMailComposer
                )
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.appTextSecondary)
                    }
                }
            }
        }
    }

    static func showsAdPrivacyChoicesRow(isPrivacyOptionsRequired: Bool) -> Bool {
        isPrivacyOptionsRequired
    }

    private var selectedScheme: ColorScheme? {
        switch appColorScheme {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    private var correctHighlightRow: some View {
        HStack {
            Text("Highlight Correct Answer")
                .font(AppFont.body(15))
                .foregroundColor(.appTextPrimary)

            Spacer()

            Toggle("", isOn: $settings.crosswordCorrectHighlight)
                .tint(.appAccent)
        }
        .listRowBackground(Color.appSurface)
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }

    private var sendFeedbackRow: some View {
        Button {
            sendFeedback()
        } label: {
            HStack {
                Text("Send Feedback")
                    .font(AppFont.body(15))
                    .foregroundColor(.appTextPrimary)

                Spacer()

                Image(systemName: "envelope")
                    .foregroundColor(.appTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(isFeedbackRowPressed ? Color.appAccent.opacity(0.14) : Color.appSurface)
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isFeedbackRowPressed = true
                }
                .onEnded { _ in
                    isFeedbackRowPressed = false
                }
        )
    }

    private func sendFeedback() {
        let content = FeedbackEmailContent.current

        if MailComposerView.canSendMail {
            isShowingMailComposer = true
        } else if let mailtoURL = content.mailtoURL {
            openURL(mailtoURL)
        }
    }

    private var adPrivacyChoicesRow: some View {
        Button {
            Task {
                await adService.presentPrivacyOptionsForm()
            }
        } label: {
            HStack {
                Text("Ad Privacy Choices")
                    .font(AppFont.body(15))
                    .foregroundColor(.appTextPrimary)

                Spacer()

                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.appTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(isAdPrivacyChoicesRowPressed ? Color.appAccent.opacity(0.14) : Color.appSurface)
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isAdPrivacyChoicesRowPressed = true
                }
                .onEnded { _ in
                    isAdPrivacyChoicesRowPressed = false
                }
        )
    }

    private func legalLinkRow(_ link: LegalLink) -> some View {
        Button {
            openURL(link.url)
        } label: {
            HStack {
                Text(link.title)
                    .font(AppFont.body(15))
                    .foregroundColor(.appTextPrimary)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(AppFont.caption())
                    .foregroundColor(.appTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.appSurface)
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }

    private var appVersionFooter: some View {
        Text(AppVersionInfo.current.displayText)
            .font(AppFont.caption())
            .foregroundColor(.appTextSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.appBackground)
    }

    private var letterFeedbackTitle: some View {
        Text("Letter Feedback")
            .fixedSize(horizontal: true, vertical: false)
            .font(AppFont.body(15))
            .lineLimit(2)
            .foregroundColor(storeService.isProUser ? .appTextPrimary : .appTextSecondary)
    }

    private var letterFeedbackToggle: some View {
        Toggle("", isOn: Binding(
            get: { settings.backwordLetterFeedback },
            set: { newValue in
                guard storeService.isProUser else { return }
                settings.backwordLetterFeedback = newValue
            }
        ))
        .tint(.appAccent)
        .disabled(!storeService.isProUser)
    }

    private var hLetterFeedbackContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    letterFeedbackTitle
                    if !storeService.isProUser {
                        proTag
                    }
                }
            }

            Spacer()
            letterFeedbackToggle
        }
    }

    private var vLetterFeedbackContent: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 26) {
                letterFeedbackTitle
                if !storeService.isProUser {
                    proTag
                }
            }

            Spacer()
            letterFeedbackToggle
            Spacer()
        }
    }

    private var letterFeedbackRow: some View {
        ViewThatFits {
            hLetterFeedbackContent
            vLetterFeedbackContent
        }
        .listRowBackground(Color.appSurface)
    }

    private var proTag: some View {
        Text("PRO")
            .font(AppFont.clueLabel(9))
            .foregroundColor(.appAccent)
            .tracking(1)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.appAccent, lineWidth: 1)
            )
    }
}

#Preview {
    SettingsView()
        .environmentObject(StoreService())
        .environmentObject(AdService())
}
