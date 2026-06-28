import Testing
@testable import Backword

@Suite("Ad service recovery")
struct AdServiceRecoveryTests {
    @Test("Google full-screen ad controller class names are recognised")
    func googleFullScreenAdControllerClassNamesAreRecognised() {
        #expect(AdService.isGoogleFullScreenAdControllerClassName("GADFullScreenAdViewController"))
        #expect(AdService.isGoogleFullScreenAdControllerClassName("GoogleMobileAds.FullScreenAdViewController"))
    }

    @Test("Non-Google controller class names are ignored")
    func nonGoogleControllerClassNamesAreIgnored() {
        #expect(!AdService.isGoogleFullScreenAdControllerClassName("UIHostingController<HomeView>"))
        #expect(!AdService.isGoogleFullScreenAdControllerClassName("UIAlertController"))
    }
}
