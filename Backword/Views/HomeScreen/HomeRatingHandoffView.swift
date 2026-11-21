import SwiftUI

struct HomeRatingHandoffAnchors: PreferenceKey {
    struct GuideTrack {
        let bounds: Anchor<CGRect>
        let fraction: Double
    }

    struct Value {
        var home: Anchor<CGRect>?
        var guide: GuideTrack?
    }

    static var defaultValue: Value { Value() }

    static func reduce(value: inout Value, nextValue: () -> Value) {
        let next = nextValue()
        value.home = next.home ?? value.home
        value.guide = next.guide ?? value.guide
    }
}

struct HomeRatingHandoff {
    struct Track {
        let frame: CGRect
        let fraction: Double
    }

    let source: Track
    let destination: Track

    init?(source: Track, destination: Track, viewport: CGRect) {
        guard !source.frame.isEmpty, !destination.frame.isEmpty,
              viewport.contains(source.frame), viewport.contains(destination.frame) else { return nil }
        self.source = source
        self.destination = destination
    }

    func track(at progress: Double) -> Track {
        let from = source.frame
        let to = destination.frame
        let amount = CGFloat(progress)
        return Track(
            frame: CGRect(
                x: from.minX + (to.minX - from.minX) * amount,
                y: from.minY + (to.minY - from.minY) * amount,
                width: from.width + (to.width - from.width) * amount,
                height: from.height + (to.height - from.height) * amount
            ),
            fraction: source.fraction + (destination.fraction - source.fraction) * progress
        )
    }
}

struct HomeRatingHandoffView: View, Animatable {
    let handoff: HomeRatingHandoff
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        let track = handoff.track(at: progress)
        RatingProgressTrack(
            fraction: track.fraction,
            style: .detailed(markerColor: RatingTier.forFraction(track.fraction).color,
                             pulses: false, markerAnimationDelay: 0),
            animates: true,
            animatesProgressChanges: false
        )
        .frame(width: track.frame.width, height: track.frame.height)
        .position(x: track.frame.midX, y: track.frame.midY)
        .animation(nil, value: progress)
    }
}
