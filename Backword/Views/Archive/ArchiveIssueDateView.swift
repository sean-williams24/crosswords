import SwiftUI

struct ArchiveIssueDateView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let issueNumber: String?
    let formattedDate: String
    let accentColor: Color

    var body: some View {
        Group {
            if ArchiveIssueDateLayout.stacksVertically(for: dynamicTypeSize) {
                VStack(alignment: .leading, spacing: 2) {
                    metadata
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    metadata
                }
            }
        }
    }

    @ViewBuilder
    private var metadata: some View {
        if let issueNumber {
            Text(issueNumber)
                .font(AppFont.clueLabel(16))
                .foregroundStyle(accentColor)
        }

        Text(formattedDate)
            .font(AppFont.body())
            .foregroundStyle(Color.appTextPrimary)
    }
}

enum ArchiveIssueDateLayout {
    static func stacksVertically(for dynamicTypeSize: DynamicTypeSize) -> Bool {
        dynamicTypeSize > .xxxLarge
    }
}
