import Testing
@testable import Backword

@Suite("Native Google Sign-In")
struct GoogleNativeSignInServiceTests {
    @Test("Explains when iOS cannot present the Google account picker")
    func unavailableErrorMessage() {
        #expect(
            GoogleNativeSignInError.unavailable.errorDescription ==
                "Google Sign-In could not be opened. Please try again."
        )
    }

    @Test("Explains a Google response with no usable identity token")
    func missingIDTokenErrorMessage() {
        #expect(
            GoogleNativeSignInError.missingIDToken.errorDescription ==
                "Google Sign-In did not return an identity token. Please try again."
        )
    }
}
