import SwiftUI
import UIKit

struct ZoomableView<Content: View>: UIViewRepresentable {
    let minZoom: CGFloat
    let maxZoom: CGFloat
    /// When true (elevated Dynamic Type size) the content is allowed to grow taller than
    /// the scroll view frame; the user can then scroll vertically to reach every cell.
    /// When false (default type) the content is constrained to exactly the frame height,
    /// preserving the original "squish to fit" layout behaviour.
    let allowsVerticalOverflow: Bool
    let content: Content

    init(minZoom: CGFloat = 1.0, maxZoom: CGFloat = 2.5, allowsVerticalOverflow: Bool = false, @ViewBuilder content: () -> Content) {
        self.minZoom = minZoom
        self.maxZoom = maxZoom
        self.allowsVerticalOverflow = allowsVerticalOverflow
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = FittingScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = minZoom
        scrollView.maximumZoomScale = maxZoom
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .clear

        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        scrollView.addSubview(hostingController.view)
        context.coordinator.hostingView = hostingController.view

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
        ])

        // Width always follows the viewport so rotation reflows the grid horizontally.
        // `allowsVerticalOverflow = true` only relaxes height, then zoom fits the board
        // back into the visible area.
        let widthEq = hostingController.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        let widthGe = hostingController.view.widthAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.widthAnchor)
        let heightEq = hostingController.view.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        let heightGe = hostingController.view.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor)
        context.coordinator.widthEqConstraint = widthEq
        context.coordinator.widthGeConstraint = widthGe
        context.coordinator.heightEqConstraint = heightEq
        context.coordinator.heightGeConstraint = heightGe
        applyOverflowConstraints(widthEq: widthEq, widthGe: widthGe, heightEq: heightEq, heightGe: heightGe, overflow: allowsVerticalOverflow)

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
        context.coordinator.scrollView = scrollView
        context.coordinator.configuredMinZoom = minZoom
        context.coordinator.maxZoom = maxZoom
        scrollView.onBoundsChange = { [weak coordinator = context.coordinator] in
            coordinator?.resetToFitAfterBoundsChange()
        }

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.configuredMinZoom = minZoom
        context.coordinator.maxZoom = maxZoom
        if let wEq = context.coordinator.widthEqConstraint,
           let wGe = context.coordinator.widthGeConstraint,
           let hEq = context.coordinator.heightEqConstraint,
           let hGe = context.coordinator.heightGeConstraint {
            applyOverflowConstraints(widthEq: wEq, widthGe: wGe, heightEq: hEq, heightGe: hGe, overflow: allowsVerticalOverflow)
        }
        scrollView.setNeedsLayout()
        DispatchQueue.main.async {
            context.coordinator.refitIfNeeded(force: false, animated: false)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            context.coordinator.refitIfNeeded(force: false, animated: false)
        }
    }

    private func applyOverflowConstraints(
        widthEq: NSLayoutConstraint, widthGe: NSLayoutConstraint,
        heightEq: NSLayoutConstraint, heightGe: NSLayoutConstraint,
        overflow: Bool
    ) {
        if overflow {
            widthEq.priority = .required
            heightEq.priority = .defaultLow
            widthGe.isActive = false
            heightGe.isActive = true
            widthEq.isActive = true
            heightEq.isActive = true
        } else {
            widthGe.isActive = false
            heightGe.isActive = false
            widthEq.priority = .required
            heightEq.priority = .required
            widthEq.isActive = true
            heightEq.isActive = true
        }
    }

    class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingView: UIView?
        weak var scrollView: UIScrollView?
        var configuredMinZoom: CGFloat = 1.0
        var maxZoom: CGFloat = 2.5
        var widthEqConstraint: NSLayoutConstraint?
        var widthGeConstraint: NSLayoutConstraint?
        var heightEqConstraint: NSLayoutConstraint?
        var heightGeConstraint: NSLayoutConstraint?
        private var lastViewportSize: CGSize = .zero
        private var lastContentSize: CGSize = .zero
        private var pendingAnimatedFitReset: DispatchWorkItem?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            hostingView
        }

        func scrollViewDidLayoutSubviews(_ scrollView: UIScrollView) {
            refitIfNeeded(force: false, animated: false)
        }

        func resetToFitAfterBoundsChange() {
            pendingAnimatedFitReset?.cancel()

            let workItem = DispatchWorkItem { [weak self] in
                self?.refitIfNeeded(force: true, animated: true)
            }
            pendingAnimatedFitReset = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: workItem)
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = scrollView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let location = gesture.location(in: scrollView)
                let zoomRect = zoomRectForScale(maxZoom, center: location, in: scrollView)
                scrollView.zoom(to: zoomRect, animated: true)
            }
        }

        private func zoomRectForScale(_ scale: CGFloat, center: CGPoint, in scrollView: UIScrollView) -> CGRect {
            let size = CGSize(
                width: scrollView.bounds.width / scale,
                height: scrollView.bounds.height / scale
            )
            let origin = CGPoint(
                x: center.x - size.width / 2,
                y: center.y - size.height / 2
            )
            return CGRect(origin: origin, size: size)
        }

        func refitIfNeeded(force: Bool, animated: Bool) {
            guard let scrollView, let hostingView else { return }

            scrollView.layoutIfNeeded()
            hostingView.layoutIfNeeded()

            let viewportSize = scrollView.bounds.size
            let contentSize = measuredContentSize(for: hostingView, viewportSize: viewportSize)
            let zoomScale = ZoomableViewScalePolicy.fitZoomScale(
                viewportSize: viewportSize,
                contentSize: contentSize,
                configuredMinZoom: configuredMinZoom,
                maxZoom: maxZoom
            )

            guard zoomScale > 0 else { return }

            scrollView.maximumZoomScale = max(maxZoom, zoomScale)
            scrollView.minimumZoomScale = zoomScale

            if ZoomableViewScalePolicy.shouldResetToFit(
                force: force,
                viewportSize: viewportSize,
                previousViewportSize: lastViewportSize,
                contentSize: contentSize,
                previousContentSize: lastContentSize,
                currentZoomScale: scrollView.zoomScale,
                fitZoomScale: zoomScale
            ) {
                scrollView.setZoomScale(zoomScale, animated: animated)
                centerContent(in: scrollView)
            }

            lastViewportSize = viewportSize
            lastContentSize = contentSize
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerContent(in: scrollView)
        }

        private func centerContent(in scrollView: UIScrollView) {
            guard let hostingView else { return }

            let horizontalInset = max((scrollView.bounds.width - hostingView.frame.width) / 2, 0)
            let verticalInset = max((scrollView.bounds.height - hostingView.frame.height) / 2, 0)
            scrollView.contentInset = UIEdgeInsets(
                top: verticalInset,
                left: horizontalInset,
                bottom: verticalInset,
                right: horizontalInset
            )
        }

        private func measuredContentSize(for hostingView: UIView, viewportSize: CGSize) -> CGSize {
            let fittingSize = hostingView.sizeThatFits(
                CGSize(width: viewportSize.width, height: CGFloat.greatestFiniteMagnitude)
            )
            return ZoomableViewScalePolicy.preferredContentSize(measuredSize: fittingSize, fallbackSize: hostingView.bounds.size)
        }
    }
}

private final class FittingScrollView: UIScrollView {
    var onBoundsChange: (() -> Void)?
    private var lastBoundsSize: CGSize = .zero

    override func layoutSubviews() {
        super.layoutSubviews()

        guard !ZoomableViewScalePolicy.sizesAreClose(bounds.size, lastBoundsSize) else { return }
        lastBoundsSize = bounds.size
        onBoundsChange?()
    }
}

enum ZoomableViewScalePolicy {
    static func preferredContentSize(measuredSize: CGSize, fallbackSize: CGSize) -> CGSize {
        guard measuredSize.width > 0,
              measuredSize.height > 0,
              measuredSize.width.isFinite,
              measuredSize.height.isFinite else {
            return fallbackSize
        }

        return measuredSize
    }

    static func fitZoomScale(
        viewportSize: CGSize,
        contentSize: CGSize,
        configuredMinZoom: CGFloat,
        maxZoom: CGFloat
    ) -> CGFloat {
        guard viewportSize.width > 0,
              viewportSize.height > 0,
              contentSize.width > 0,
              contentSize.height > 0 else {
            return configuredMinZoom
        }

        let widthScale = viewportSize.width / contentSize.width
        let heightScale = viewportSize.height / contentSize.height
        let fitScale = min(widthScale, heightScale, configuredMinZoom)
        return min(max(fitScale, 0.01), maxZoom)
    }

    static func sizesAreClose(_ lhs: CGSize, _ rhs: CGSize, tolerance: CGFloat = 0.5) -> Bool {
        abs(lhs.width - rhs.width) <= tolerance && abs(lhs.height - rhs.height) <= tolerance
    }

    static func shouldResetToFit(
        force: Bool,
        viewportSize: CGSize,
        previousViewportSize: CGSize,
        contentSize: CGSize,
        previousContentSize: CGSize,
        currentZoomScale: CGFloat,
        fitZoomScale: CGFloat
    ) -> Bool {
        force
            || !sizesAreClose(viewportSize, previousViewportSize)
            || !sizesAreClose(contentSize, previousContentSize)
            || currentZoomScale < fitZoomScale
    }
}
