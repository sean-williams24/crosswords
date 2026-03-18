import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var storeService: StoreService
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlan: Plan = .annual
    @State private var isBreathing = false
    @State private var errorMessage: String?

    enum Plan { case monthly, annual }

    var body: some View {
        ZStack {
            // Blurred background
            Color.appBackground.opacity(0.3)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 0) {
                // Dismiss button
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .symbolRenderingMode(.hierarchical)
                            .foregroundColor(.appTextSecondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)

                Spacer().frame(height: 16)

                // Hero mini-grid
                miniGrid
                    .padding(.horizontal, 48)

                Spacer().frame(height: 28)

                // Header
                VStack(spacing: 6) {
                    Text("Crosswords Pro")
                        .font(AppFont.header(28))
                        .foregroundColor(.appTextPrimary)

                    Text("The full crossword experience")
                        .font(AppFont.body(15))
                        .foregroundColor(.appTextSecondary)
                }

                Spacer().frame(height: 28)

                // Feature list
                featureList
                    .padding(.horizontal, 32)

                Spacer().frame(height: 32)

                // Plan toggle
                planToggle
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
                    .font(.system(size: 10))
                    .foregroundColor(.appTextSecondary.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)
            }
        }
        .interactiveDismissDisabled(storeService.purchaseInProgress)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                isBreathing = true
            }
        }
    }

    // MARK: - Mini Grid Hero

    private var miniGrid: some View {
        let letters: [[Character?]] = [
            [nil, nil, "W", nil, nil],
            ["C", "R", "O", "S", "S"],
            [nil, nil, "R", nil, nil],
            [nil, nil, "D", nil, nil],
            [nil, nil, nil, nil, nil],
        ]

        return Grid(horizontalSpacing: 3, verticalSpacing: 3) {
            ForEach(0..<5, id: \.self) { row in
                GridRow {
                    ForEach(0..<5, id: \.self) { col in
                        if let letter = letters[row][col] {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.appAccent.opacity(0.12))
                                .overlay(
                                    Text(String(letter))
                                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                        .foregroundColor(.appAccent)
                                )
                                .aspectRatio(1, contentMode: .fit)
                        } else if letters[row][col] == nil && (row < 4 || col < 3) {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.appSurface)
                                .aspectRatio(1, contentMode: .fit)
                        } else {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.appGridLine.opacity(0.3))
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: 160)
    }

    // MARK: - Feature List

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 14) {
            featureRow(icon: "archivebox.fill", text: "Unlimited puzzle archive")
            featureRow(icon: "lightbulb.fill", text: "Unlimited hints")
            featureRow(icon: "eye.slash.fill", text: "Ad-free experience")
            featureRow(icon: "flame.fill", text: "Support indie development")
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
        }
    }

    // MARK: - Plan Toggle

    private var planToggle: some View {
        HStack(spacing: 0) {
            planOption(
                title: "Monthly",
                price: storeService.monthlyProduct?.displayPrice ?? "£1.99",
                subtitle: "per month",
                plan: .monthly
            )

            planOption(
                title: "Annual",
                price: storeService.annualProduct?.displayPrice ?? "£15.99",
                subtitle: "per year · Save 33%",
                plan: .annual
            )
        }
        .background(Color.appSurface)
        .cornerRadius(AppLayout.cardCornerRadius)
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
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.appAccent)
            .cornerRadius(AppLayout.cardCornerRadius)
            .scaleEffect(isBreathing ? 1.02 : 1.0)
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

// MARK: - Preview

#Preview {
    PaywallView()
        .environmentObject(StoreService())
}
