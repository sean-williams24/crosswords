//
//  BackwordLogo.swift

import SwiftUI

struct BackwordLogo: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Image(logoName)
            .resizable()
            .scaledToFit()
            .frame(height: 38)
    }

    private var logoName: String {
        colorScheme == .light ? "BackWordLogo - Light" : "BackWordLogo"
    }
}
