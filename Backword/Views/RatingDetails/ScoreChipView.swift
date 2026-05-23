//  ScoreChipView.swift

import SwiftUI

struct ScoreChipView: View {
    @ScaledMetric private var chipSize: CGFloat = 24
    let score: Int

//    let color: Color = !hasEntry ? .appTextSecondary.opacity(0.1)
//        : score == 5 ? .appCorrect
//        : score > 0 ? .appAccent
//        : .appTextSecondary.opacity(0.25)
//    let textColor: Color = hasEntry && score > 0 ? .white : .appTextSecondary.opacity(0.4)
//    
    var body: some View {
        let color: Color = score == 5 ? .appCorrect : score > 0 ? .appAccent : .appTextSecondary.opacity(0.25)
        return Text("\(score)")
            .font(AppFont.clueLabel(12))
            .foregroundColor(score > 0 ? .white : .appTextSecondary.opacity(0.4))
            .frame(width: chipSize, height: chipSize)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    ScoreChipView(score: 4)
}
