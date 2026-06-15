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
