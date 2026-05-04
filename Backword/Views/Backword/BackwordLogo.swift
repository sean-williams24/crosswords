//
//  BackwordLogo.swift

import SwiftUI

struct BackwordLogo: View {
    @Environment(\.colorScheme) private var colorScheme
    var frame: CGFloat = 38

    var body: some View {
        Image(logoName)
            .resizable()
            .scaledToFit()
            .frame(height: frame)
    }

    private var logoName: String {
        colorScheme == .light ? "BackWordLogo - Light" : "BackWordLogo"
    }
}
