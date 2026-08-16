import Testing
@testable import Backword

@Suite("Google Sign-In Button")
struct GoogleSignInButtonTests {
    @Test("Uses the same geometry as the Sign in with Apple button")
    func matchesAppleButtonGeometry() {
        #expect(GoogleSignInButtonAppearance.height == 50)
        #expect(GoogleSignInButtonAppearance.cornerRadius == 6)
        #expect(GoogleSignInButtonAppearance.borderWidth == 0.5)
    }

    @Test("Uses the Google sign-in call to action")
    func usesSignInCallToAction() {
        #expect(GoogleSignInButtonAppearance.label == "Continue with Google")
    }
}
