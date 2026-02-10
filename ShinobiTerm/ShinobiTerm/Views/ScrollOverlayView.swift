import UIKit
import SwiftUI

/// Read モード中にジェスチャーを検出するオーバーレイ（パン、ピンチ、ダブルタップ）
struct ScrollOverlayView: UIViewRepresentable {
    var isZoomed: Bool
    let onScroll: (Int) -> Void
    let onScrollEnded: () -> Void
    let onPinch: (CGFloat) -> Void
    let onZoomPan: (CGPoint) -> Void
    let onDoubleTap: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.01)

        let singlePan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleSinglePan(_:))
        )
        singlePan.minimumNumberOfTouches = 1
        singlePan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(singlePan)

        let twoPan = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTwoPan(_:))
        )
        twoPan.minimumNumberOfTouches = 2
        twoPan.maximumNumberOfTouches = 2
        view.addGestureRecognizer(twoPan)

        let pinch = UIPinchGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePinch(_:))
        )
        view.addGestureRecognizer(pinch)

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)

        singlePan.require(toFail: doubleTap)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.isZoomed = isZoomed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            isZoomed: isZoomed,
            onScroll: onScroll,
            onScrollEnded: onScrollEnded,
            onPinch: onPinch,
            onZoomPan: onZoomPan,
            onDoubleTap: onDoubleTap
        )
    }

    class Coordinator: NSObject {
        var isZoomed: Bool
        let onScroll: (Int) -> Void
        let onScrollEnded: () -> Void
        let onPinch: (CGFloat) -> Void
        let onZoomPan: (CGPoint) -> Void
        let onDoubleTap: () -> Void
        private var accumulatedDelta: CGFloat = 0
        private let lineHeight: CGFloat = 16

        init(
            isZoomed: Bool,
            onScroll: @escaping (Int) -> Void,
            onScrollEnded: @escaping () -> Void,
            onPinch: @escaping (CGFloat) -> Void,
            onZoomPan: @escaping (CGPoint) -> Void,
            onDoubleTap: @escaping () -> Void
        ) {
            self.isZoomed = isZoomed
            self.onScroll = onScroll
            self.onScrollEnded = onScrollEnded
            self.onPinch = onPinch
            self.onZoomPan = onZoomPan
            self.onDoubleTap = onDoubleTap
        }

        @objc func handleSinglePan(_ gesture: UIPanGestureRecognizer) {
            if isZoomed {
                // ズーム中は1本指パンでビュー移動
                switch gesture.state {
                case .changed:
                    let translation = gesture.translation(in: gesture.view)
                    onZoomPan(CGPoint(x: translation.x, y: translation.y))
                    gesture.setTranslation(.zero, in: gesture.view)
                default:
                    break
                }
                return
            }

            switch gesture.state {
            case .changed:
                let translation = gesture.translation(in: gesture.view)
                accumulatedDelta += translation.y
                let lines = Int(accumulatedDelta / lineHeight)
                if lines != 0 {
                    onScroll(-lines)
                    accumulatedDelta -= CGFloat(lines) * lineHeight
                }
                gesture.setTranslation(.zero, in: gesture.view)
            case .ended, .cancelled:
                accumulatedDelta = 0
                onScrollEnded()
            default:
                break
            }
        }

        @objc func handleTwoPan(_ gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .changed:
                let translation = gesture.translation(in: gesture.view)
                onZoomPan(CGPoint(x: translation.x, y: translation.y))
                gesture.setTranslation(.zero, in: gesture.view)
            default:
                break
            }
        }

        @objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
            switch gesture.state {
            case .changed:
                onPinch(gesture.scale)
                gesture.scale = 1.0
            default:
                break
            }
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            onDoubleTap()
        }
    }
}
