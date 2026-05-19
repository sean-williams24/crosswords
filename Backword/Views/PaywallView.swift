import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var storeService: StoreService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @ScaledMetric private var proLogoFrame: CGFloat = 48
    @ScaledMetric private var proLogoOffset: CGFloat = 34
    @ScaledMetric private var proLogoVStackSpacing: CGFloat = -29

    @State private var selectedPlan: Plan = .annual
    @State private var isBreathing = false
    @State private var errorMessage: String?
    @State private var logoVisible = false
    @State private var proLogoVisible = false
    
    enum Plan { case monthly, annual }

    var body: some View {
        ScrollView {
            ZStack {
                VStack(spacing: 0) {
                    // Black hero extends behind the top of the sheet
                    ZStack {
                        VStack(spacing: proLogoVStackSpacing) {
                            BackwordLogo(frame: 78, forceDark: true)
                                .offset(x: logoVisible ? 0 : 120)
                                .opacity(logoVisible ? 1 : 0)

                            Image("Pro")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: proLogoFrame)
                                .offset(x: proLogoOffset)
                                .opacity(proLogoVisible ? 1 : 0)
                                .scaleEffect(isBreathing ? 1.09 : 1.0)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(height: 240)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.ignoresSafeArea(edges: .top))

                    // Lower content on app background
                    VStack(spacing: 0) {
                        Spacer().frame(height: 28)

                        // Header
                        Text("The full crossword experience")
                            .font(AppFont.header(15))
                            .foregroundColor(.appTextPrimary)
                            .padding(.horizontal, AppLayout.screenPadding)

                        Spacer().frame(height: 28)

                        // Feature list
                        featureList
                            .padding(.horizontal, 32)

                        Spacer().frame(height: 32)

                        // Plan toggle
                        planToggle
                            .background(Color.appSurface)
                            .cornerRadius(AppLayout.cardCornerRadius)
                            .padding(.horizontal, 32)

                        Spacer().frame(height: 24)

                        // CTA button
                        ctaButton
                            .padding(.horizontal, 32)

                        // Error
                        if let errorMessage {
                            Text(errorMessage)
                                .font(AppFont.caption())
                                .foregroundColor(.red)
                                .padding(.top, 8)
                        }

                        Spacer().frame(height: 12)

                        // Restore + legal
                        Button("Restore Purchases") {
                            Task { await storeService.restorePurchases() }
                        }
                        .font(AppFont.caption())
                        .foregroundColor(.appTextSecondary)

                        Spacer().frame(height: 8)

                        Text("Payment will be charged to your Apple ID account at confirmation of purchase. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.")
                            .font(AppFont.clueNumber(10))
                            .foregroundColor(.appTextSecondary.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                            .padding(.bottom, 20)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.appBackground)
                }

                // Dismiss button floats over the black hero
                VStack {
                    HStack {
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .symbolRenderingMode(.hierarchical)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    Spacer()
                }
            }
            .blackSheetBackground()
            .interactiveDismissDisabled(storeService.purchaseInProgress)
            .onAppear {
                animateLogo()
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    isBreathing = true
                }
            }
        }
    }

    private func animateLogo() {
        Task {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms — next render cycle
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                logoVisible = true
            }

            try? await Task.sleep(nanoseconds: 200_000_000)
            withAnimation(.easeIn) {
                proLogoVisible = true
            }
        }
    }

    // MARK: - Feature List

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            featureRow(icon: "brain.head.profile", text: "Weekly challenging puzzles")
            featureRow(icon: "archivebox.fill", text: "Unlimited puzzle archive")
            featureRow(icon: "lightbulb.fill", text: "Unlimited hints")
            featureRow(icon: "eye.slash.fill", text: "Ad-free experience")
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(.appAccent)
                .frame(width: 24)

            Text(text)
                .font(AppFont.body(15))
                .foregroundColor(.appTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Plan Toggle

    private var isLargeContent: Bool {
        dynamicTypeSize > .accessibility3
    }

    @ViewBuilder
    private var planToggle: some View {
        if isLargeContent {
            verticalPlanToggle
        } else {
            horizontalPlanToggle
        }
    }

    private var horizontalPlanToggle: some View {
        HStack(spacing: 0) {
            monthlyPlanOption
            annualPlanOption
        }
    }

    private var verticalPlanToggle: some View {
        VStack {
            monthlyPlanOption
            annualPlanOption
        }
    }

    private var monthlyPlanOption: some View {
        planOption(
            title: "Monthly",
            price: storeService.monthlyProduct?.displayPrice ?? "£1.49",
            subtitle: "per month",
            plan: .monthly
        )
    }

    private var annualPlanOption: some View {
        planOption(
            title: "Annual",
            price: storeService.annualProduct?.displayPrice ?? "£11.99",
            subtitle: "per year · Save 33%",
            plan: .annual
        )
    }

    private func planOption(title: String, price: String, subtitle: String, plan: Plan) -> some View {
        let isSelected = selectedPlan == plan

        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedPlan = plan
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            VStack(spacing: 4) {
                Text(title)
                    .font(AppFont.clueLabel(12))
                    .foregroundColor(isSelected ? .appAccent : .appTextSecondary)
                    .tracking(1)

                Text(price)
                    .font(AppFont.header(20))
                    .foregroundColor(isSelected ? .appTextPrimary : .appTextSecondary)

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.appTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: AppLayout.cardCornerRadius)
                    .stroke(isSelected ? Color.appAccent : Color.clear, lineWidth: 2)
            )
        }
    }

    // MARK: - CTA Button

    private var ctaButton: some View {
        Button {
            Task { await purchase() }
        } label: {
            Group {
                if storeService.purchaseInProgress {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Start 7-Day Free Trial")
                        .font(AppFont.clueLabel(16))
                        .tracking(0.5)
                        .padding(.horizontal, 5)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.appAccent)
            .cornerRadius(AppLayout.cardCornerRadius)
            .scaleEffect(isBreathing ? 1.05 : 1.0)
        }
        .disabled(storeService.purchaseInProgress)
    }

    // MARK: - Purchase Logic

    private func purchase() async {
        errorMessage = nil

        let product: Product? = selectedPlan == .monthly
            ? storeService.monthlyProduct
            : storeService.annualProduct

        guard let product else {
            errorMessage = "Product not available. Please try again."
            return
        }

        do {
            try await storeService.purchase(product)
            if storeService.isProUser {
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Helpers

private extension View {
    @ViewBuilder
    func blackSheetBackground() -> some View {
        if #available(iOS 16.4, *) {
            self.presentationBackground(Color.black)
        } else {
            self
        }
    }
}

// MARK: - Preview

#Preview {
    PaywallView()
        .environmentObject(StoreService())
}
