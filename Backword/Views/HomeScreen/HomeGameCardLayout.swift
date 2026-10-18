import SwiftUI

/// Centres branding independently of the top badges and bottom completion details.
struct HomeGameCardLayout: Layout {
    enum Region: Hashable {
        case header, identity, accessory, details
    }

    enum IdentityPosition {
        case center, top
    }

    struct RegionKey: LayoutValueKey {
        static let defaultValue = Region.identity
    }

    struct Frames {
        let header: CGRect
        let identity: CGRect
        let accessory: CGRect
        let details: CGRect

        var size: CGSize { CGSize(width: identity.width, height: details.maxY) }

        subscript(region: Region) -> CGRect {
            switch region {
            case .header: header
            case .identity: identity
            case .accessory: accessory
            case .details: details
            }
        }
    }

    let minimumHeight: CGFloat
    let spacing: CGFloat
    var identityPosition: IdentityPosition = .center
    var fillsProposedHeight = false

    static func frames(
        width: CGFloat, minimumHeight: CGFloat, heights: [Region: CGFloat], spacing: CGFloat,
        identityPosition: IdentityPosition = .center
    ) -> Frames {
        let headerHeight = heights[.header, default: 0]
        let identityHeight = heights[.identity, default: 0]
        let detailsHeight = heights[.details, default: 0]
        let accessoryHeight = heights[.accessory, default: 0]
        let accessorySpacing = accessoryHeight > 0 ? spacing : 0
        let brandingHeight = identityHeight + accessorySpacing + accessoryHeight
        let footerInset = detailsHeight > 0 ? detailsHeight + spacing : 0
        let height: CGFloat
        let identityY: CGFloat
        switch identityPosition {
        case .center:
            let headerInset = headerHeight > 0 ? headerHeight + spacing : 0
            height = max(minimumHeight, brandingHeight + 2 * max(headerInset, footerInset))
            identityY = (height - brandingHeight) / 2
        case .top:
            // Completed Backword keeps its logo above the cells, beside the streak.
            height = max(minimumHeight, max(headerHeight, brandingHeight) + footerInset)
            identityY = 0
        }
        return Frames(
            header: CGRect(x: 0, y: 0, width: width, height: headerHeight),
            identity: CGRect(x: 0, y: identityY, width: width, height: identityHeight),
            accessory: CGRect(x: 0, y: identityY + identityHeight + accessorySpacing, width: width, height: accessoryHeight),
            details: CGRect(x: 0, y: height - detailsHeight, width: width, height: detailsHeight)
        )
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let frames = Self.frames(
            width: width,
            minimumHeight: fillsProposedHeight ? max(minimumHeight, proposal.height ?? 0) : minimumHeight,
            heights: heights(for: subviews, width: width), spacing: spacing, identityPosition: identityPosition
        )
        return frames.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frames = Self.frames(
            width: bounds.width, minimumHeight: bounds.height,
            heights: heights(for: subviews, width: bounds.width), spacing: spacing, identityPosition: identityPosition
        )
        for subview in subviews {
            let frame = frames[subview[RegionKey.self]]
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading, proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func heights(for subviews: Subviews, width: CGFloat) -> [Region: CGFloat] {
        var heights: [Region: CGFloat] = [:]
        for subview in subviews {
            let region = subview[RegionKey.self]
            let height = subview.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
            heights[region] = max(heights[region, default: 0], height)
        }
        return heights
    }
}
