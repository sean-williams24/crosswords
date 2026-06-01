//  ToolTip.swift

import SwiftUI

struct TooltipModel {
    let id = UUID().uuidString
    var icon: String? = nil
    let title: String
}

enum TooltipDirection {
    case top
    case left
    case right
    case bottom
}

struct Tooltip: View {
    var items: [TooltipModel]
    var type: TooltipDirection
    var horizontalAlignment: HorizontalAlignment = .center

    public var body: some View {
        Group {
            switch type {
            case .bottom: // Tooltip below the view (Triangle points UP)
                VStack(alignment: horizontalAlignment, spacing: 0) {
                    triangle()
                        .padding(horizontalPadding)
                    bubble()
                }
            case .top: // Tooltip above the view (Triangle points DOWN)
                VStack(alignment: horizontalAlignment, spacing: 0) {
                    bubble()
                    triangle()
                        .rotationEffect(.degrees(180))
                        .padding(horizontalPadding)
                }
            case .left: // Tooltip to the left (Triangle points RIGHT)
                HStack(spacing: 0) {
                    bubble()
                    triangle()
                        .rotationEffect(.degrees(90))
                }
            case .right: // Tooltip to the right (Triangle points LEFT)
                HStack(spacing: 0) {
                    triangle()
                        .rotationEffect(.degrees(-90))
                    bubble()
                }
            }
        }
    }

    // MARK: - Subviews

    private func bubble() -> some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.id) { item in
                ActivityItem(item: item)
            }
        }
        .padding(8)
        .background(Color.appAccent.opacity(0.9))
        .cornerRadius(8)
    }

    private func ActivityItem(item: TooltipModel) -> some View {
        HStack(spacing: 2) {
            if let icon = item.icon {
                Image(icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            }
            Text(item.title)
                .font(AppFont.caption())
                .lineLimit(1)
                .foregroundStyle(.white)
        }
    }

    private func triangle() -> some View {
        Triangle()
            .fill(Color.appAccent.opacity(0.9))
            .frame(width: 20, height: 10)
    }

    // MARK: - Helpers

    // Pushes the triangle slightly inward from the corner radius so it lines up with the icon
    private var horizontalPadding: EdgeInsets {
        if horizontalAlignment == .trailing {
            return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 12)
        } else if horizontalAlignment == .leading {
            return EdgeInsets(top: 0, leading: 12, bottom: 0, trailing: 0)
        }
        return EdgeInsets()
    }
}

#Preview {
    Image(systemName: "info.circle")
//        .tooltip(
//            isPresented: ),
//            items: [.init(title: "Check this shit")],
//            direction: .bottom,
//            alignment: .trailing
//        )
//    Tooltip(items: [.init(title: "Tap for settings info, change colour scheme ")], type: .top)
}
