import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Synced Horizontal Scroll View

#if os(iOS)
struct SyncedHorizontalScrollView<Content: View>: UIViewRepresentable {
    let showsHorizontalScrollIndicator: Bool
    let onOffsetChange: (CGFloat) -> Void
    let content: AnyView

    init(
        showsHorizontalScrollIndicator: Bool = false,
        onOffsetChange: @escaping (CGFloat) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.showsHorizontalScrollIndicator = showsHorizontalScrollIndicator
        self.onOffsetChange = onOffsetChange
        self.content = AnyView(content())
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onOffsetChange: onOffsetChange)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.showsHorizontalScrollIndicator = showsHorizontalScrollIndicator
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.bounces = true
        scrollView.alwaysBounceVertical = false
        scrollView.clipsToBounds = true

        let host = context.coordinator.hostingController
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(host.view)

        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            host.view.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.onOffsetChange = onOffsetChange
        context.coordinator.hostingController.rootView = content
        context.coordinator.hostingController.view.invalidateIntrinsicContentSize()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var onOffsetChange: (CGFloat) -> Void
        let hostingController = UIHostingController(rootView: AnyView(EmptyView()))

        init(onOffsetChange: @escaping (CGFloat) -> Void) {
            self.onOffsetChange = onOffsetChange
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            onOffsetChange(-scrollView.contentOffset.x)
        }
    }
}
#endif
