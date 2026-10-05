import SwiftUI

struct MidwordInstructionsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("Find the missing middle word")
                    .font(AppFont.header(28))
                Text("The middle word joins with the word above it and the word below it to make two familiar compounds.")
                    .font(AppFont.body())
                HStack(alignment: .center) {
                    Spacer()
                    Text("BANK  +  NOTE  +  BOOK")
                        .font(AppFont.header(20))
                        .foregroundColor(.midwordAccent)
                    Spacer()
                }
                HStack(alignment: .center) {
                    Spacer()
                    Text("BANKNOTE  and  NOTEBOOK")
                        .font(AppFont.body())
                    Spacer()
                }
                Text("You get five guesses. Solve it on your first try for five points, or on your fifth try for one point. An incorrect guess is marked as a whole word; no letters are revealed.")
                    .font(AppFont.body())
            }
            .foregroundColor(.appTextPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppLayout.screenPadding)
        }
        .background(Color.appBackground)
    }
}
