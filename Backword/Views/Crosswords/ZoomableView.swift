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
        let scrollView = UIScrollView()
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

        // Width and height: at default type the content is constrained to exactly the
        // frame size (squish-to-fit). At elevated Dynamic Type sizes `allowsVerticalOverflow
        // = true` switches both axes to a low-priority equality + required >= so cells can
        // grow beyond the viewport and the user can scroll/zoom in all directions.
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
        context.coordinator.maxZoom = maxZoom

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        scrollView.minimumZoomScale = minZoom
        scrollView.maximumZoomScale = maxZoom
        if let wEq = context.coordinator.widthEqConstraint,
           let wGe = context.coordinator.widthGeConstraint,
           let hEq = context.coordinator.heightEqConstraint,
           let hGe = context.coordinator.heightGeConstraint {
            applyOverflowConstraints(widthEq: wEq, widthGe: wGe, heightEq: hEq, heightGe: hGe, overflow: allowsVerticalOverflow)
        }
    }

    private func applyOverflowConstraints(
        widthEq: NSLayoutConstraint, widthGe: NSLayoutConstraint,
        heightEq: NSLayoutConstraint, heightGe: NSLayoutConstraint,
        overflow: Bool
    ) {
        if overflow {
            widthEq.priority = .defaultLow
            heightEq.priority = .defaultLow
            widthGe.isActive = true
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
        var maxZoom: CGFloat = 2.5
        var widthEqConstraint: NSLayoutConstraint?
        var widthGeConstraint: NSLayoutConstraint?
        var heightEqConstraint: NSLayoutConstraint?
        var heightGeConstraint: NSLayoutConstraint?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            hostingView
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
    }
}

