//  TooltipModifier.swift

import SwiftUI

struct TooltipModifier: ViewModifier {
    @Binding var isPresented: Bool
    @State private var isVisuallyShowing = false
    let items: [TooltipModel]
    let direction: TooltipDirection
    let alignment: HorizontalAlignment

    let presentationDelay: TimeInterval
    let duration: TooltipDuration?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: overlayAlignment) {
                if isVisuallyShowing {
                    Tooltip(items: items, type: direction, horizontalAlignment: alignment)
                        .offset(y: yOffset)
                        .offset(x: xOffset)
                        .fixedSize()
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8, anchor: animationAnchor).combined(with: .opacity),
                            removal: .scale(scale: 0.8, anchor: animationAnchor).combined(with: .opacity)
                        ))
                }
            }
            .task(id: isPresented) {
                if isPresented {
                    // 1. Wait for the Presentation Delay (e.g., let the screen finish pushing)
                    if presentationDelay > 0 {
                        try? await Task.sleep(nanoseconds: UInt64(presentationDelay * 1_000_000_000))
                    }

                    // Make sure parent hasn't cancelled it while we were waiting
                    guard !Task.isCancelled, isPresented else { return }

                    // 2. Animate the tooltip IN
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isVisuallyShowing = true
                    }

                    // 3. Wait for the Auto-Dismiss Duration
                    if let duration = duration {
                        try? await Task.sleep(nanoseconds: UInt64(duration.rawValue * 1_000_000_000))

                        guard !Task.isCancelled, isPresented else { return }

                        // 4. Animate the tooltip OUT and sync back to parent
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isVisuallyShowing = false
                            isPresented = false
                        }
                    }
                } else {
                    // If the parent manually sets isPresented to false, dismiss instantly
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isVisuallyShowing = false
                    }
                }
            }
    }

    private var overlayAlignment: Alignment {
        switch (direction, alignment) {
        case (.bottom, .trailing):
            return .bottomTrailing
        case (.bottom, .leading):
            return .bottomLeading
        case (.bottom, .center):
            return .bottom
        case (.top, .trailing):
            return .topTrailing
        case (.top, .leading):
            return .topLeading
        case (.top, .center):
            return .top
        case (.left, _):
            return .leading
        case (.right, _):
            return .trailing
        case (.top, _):
            return .top
        case (.bottom, _):
            return .bottom
        }
    }

    private var yOffset: CGFloat {
        if direction == .bottom { return 45 }
        if direction == .top { return -45 }
        return 0
    }

    private var xOffset: CGFloat {
        if direction == .left { return -100 }
        if direction == .right { return 100 }
        if direction == .bottom { return 5 }
        return 0
    }


    private var animationAnchor: UnitPoint {
        switch direction {
        case .top: return .bottom
        case .bottom: return .top
        case .left: return .trailing
        case .right: return .leading
        }
    }
}


extension View {
    func tooltip(
        isPresented: Binding<Bool>,
        items: [TooltipModel],
        direction: TooltipDirection,
        alignment: HorizontalAlignment = .center,
        presentationDelay: TimeInterval = 0,
        duration: TooltipDuration? = nil
    ) -> some View {
        self.modifier(
            TooltipModifier(
                isPresented: isPresented,
                items: items,
                direction: direction,
                alignment: alignment,
                presentationDelay: presentationDelay,
                duration: duration
            )
        )
    }
}

enum TooltipDuration: TimeInterval {
    case short = 3.0
    case medium = 6.0
    case long = 9.0
}
