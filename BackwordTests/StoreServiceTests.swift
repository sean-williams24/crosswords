import Foundation
import Testing
@testable import Backword

@Suite("StoreService Tests")
@MainActor
struct StoreServiceTests {

    @Test("Active monthly entitlement grants Pro")
    func activeMonthlyEntitlementGrantsPro() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        #expect(StoreService.grantsProAccess(
            productID: StoreService.monthlyID,
            revocationDate: nil,
            expirationDate: now.addingTimeInterval(60),
            now: now
        ))
    }

    @Test("Active annual entitlement grants Pro")
    func activeAnnualEntitlementGrantsPro() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        #expect(StoreService.grantsProAccess(
            productID: StoreService.annualID,
            revocationDate: nil,
            expirationDate: now.addingTimeInterval(60),
            now: now
        ))
    }

    @Test("Revoked entitlement does not grant Pro")
    func revokedEntitlementDoesNotGrantPro() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        #expect(!StoreService.grantsProAccess(
            productID: StoreService.annualID,
            revocationDate: now.addingTimeInterval(-60),
            expirationDate: now.addingTimeInterval(60),
            now: now
        ))
    }

    @Test("Expired entitlement does not grant Pro")
    func expiredEntitlementDoesNotGrantPro() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        #expect(!StoreService.grantsProAccess(
            productID: StoreService.monthlyID,
            revocationDate: nil,
            expirationDate: now.addingTimeInterval(-60),
            now: now
        ))
    }

    @Test("Unknown product does not grant Pro")
    func unknownProductDoesNotGrantPro() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        #expect(!StoreService.grantsProAccess(
            productID: "com.backword.not-pro",
            revocationDate: nil,
            expirationDate: now.addingTimeInterval(60),
            now: now
        ))
    }

    @Test("Next Pro expiration returns earliest active subscription expiration")
    func nextProExpirationReturnsEarliestActiveSubscriptionExpiration() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let soon = now.addingTimeInterval(60)
        let later = now.addingTimeInterval(120)

        let expiration = StoreService.nextProExpiration(from: [
            ProEntitlementSnapshot(
                productID: StoreService.annualID,
                revocationDate: nil,
                expirationDate: later
            ),
            ProEntitlementSnapshot(
                productID: StoreService.monthlyID,
                revocationDate: nil,
                expirationDate: soon
            ),
            ProEntitlementSnapshot(
                productID: "com.backword.not-pro",
                revocationDate: nil,
                expirationDate: now.addingTimeInterval(30)
            )
        ], now: now)

        #expect(expiration == soon)
    }

    @Test("Next Pro expiration ignores expired and revoked subscriptions")
    func nextProExpirationIgnoresInactiveSubscriptions() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        let expiration = StoreService.nextProExpiration(from: [
            ProEntitlementSnapshot(
                productID: StoreService.annualID,
                revocationDate: nil,
                expirationDate: now.addingTimeInterval(-60)
            ),
            ProEntitlementSnapshot(
                productID: StoreService.monthlyID,
                revocationDate: now,
                expirationDate: now.addingTimeInterval(60)
            )
        ], now: now)

        #expect(expiration == nil)
    }

    @Test("Resolved Pro status keeps active StoreKit subscription")
    func resolvedProStatusKeepsActiveStoreKitSubscription() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        #expect(StoreService.resolvedProStatus(
            hasActiveSubscription: true,
            entitlementCount: 1,
            cachedExpirationDate: nil,
            now: now
        ))
    }

    @Test("Resolved Pro status falls back to active cache when StoreKit returns no entitlements")
    func resolvedProStatusFallsBackToActiveCacheForEmptyEntitlements() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        #expect(StoreService.resolvedProStatus(
            hasActiveSubscription: false,
            entitlementCount: 0,
            cachedExpirationDate: now.addingTimeInterval(60),
            now: now
        ))
    }

    @Test("Resolved Pro status uses recently expired cache during validation grace")
    func resolvedProStatusUsesRecentlyExpiredCacheDuringValidationGrace() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        #expect(StoreService.resolvedProStatus(
            hasActiveSubscription: false,
            entitlementCount: 0,
            cachedExpirationDate: now.addingTimeInterval(-60),
            now: now
        ))
    }

    @Test("Resolved Pro status ignores stale expired cache")
    func resolvedProStatusIgnoresStaleExpiredCache() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        #expect(!StoreService.resolvedProStatus(
            hasActiveSubscription: false,
            entitlementCount: 0,
            cachedExpirationDate: now.addingTimeInterval(-4 * 24 * 60 * 60),
            now: now
        ))
    }

    @Test("Resolved Pro status does not use cache when StoreKit returns non-granting entitlements")
    func resolvedProStatusDoesNotUseCacheForNonGrantingEntitlements() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)

        #expect(!StoreService.resolvedProStatus(
            hasActiveSubscription: false,
            entitlementCount: 1,
            cachedExpirationDate: now.addingTimeInterval(60),
            now: now
        ))
    }

    #if DEBUG
    @Test("Debug override true forces Pro")
    func debugOverrideTrueForcesPro() {
        #expect(StoreService.debugEffectiveProStatus(storeKitStatus: false, override: true))
    }

    @Test("Debug override false forces Free")
    func debugOverrideFalseForcesFree() {
        #expect(!StoreService.debugEffectiveProStatus(storeKitStatus: true, override: false))
    }

    @Test("Nil debug override uses StoreKit status")
    func nilDebugOverrideUsesStoreKitStatus() {
        #expect(StoreService.debugEffectiveProStatus(storeKitStatus: true, override: nil))
        #expect(!StoreService.debugEffectiveProStatus(storeKitStatus: false, override: nil))
    }

    @Test("Debug pending simulation returns pending only when enabled")
    func debugPendingSimulationReturnsPendingOnlyWhenEnabled() {
        #expect(StoreService.debugSimulatedPurchaseOutcome(simulateNextPurchasePending: true) == .pending)
        #expect(StoreService.debugSimulatedPurchaseOutcome(simulateNextPurchasePending: false) == nil)
    }

    @Test("Debug restore simulation returns selected outcome")
    func debugRestoreSimulationReturnsSelectedOutcome() {
        #expect(StoreService.debugSimulatedRestoreOutcome(simulateNextRestoreOutcome: .restored) == .restored)
        #expect(StoreService.debugSimulatedRestoreOutcome(simulateNextRestoreOutcome: .notFound) == .notFound)
        #expect(StoreService.debugSimulatedRestoreOutcome(simulateNextRestoreOutcome: nil) == nil)
    }

    @Test("Debug entitlement diagnostic reports no entitlements")
    func debugEntitlementDiagnosticReportsNoEntitlements() {
        #expect(StoreService.debugEntitlementDiagnosticSummary(
            totalCount: 0,
            proGrantingCount: 0,
            unverifiedCount: 0
        ) == "No current entitlements returned.")
    }

    @Test("Debug entitlement diagnostic summarizes entitlement counts")
    func debugEntitlementDiagnosticSummarizesEntitlementCounts() {
        #expect(StoreService.debugEntitlementDiagnosticSummary(
            totalCount: 2,
            proGrantingCount: 1,
            unverifiedCount: 1
        ) == "2 current entitlements; 1 grants Pro; 1 unverified.")
    }
    #endif
}
