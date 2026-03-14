import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Scroll Sync Coordinator

#if os(iOS)
/// Coordinates multiple SyncedHorizontalScrollViews so only one is the
/// active "leader" at any time. When a new scroll view is touched, the
/// previous leader's deceleration is stopped immediately.
final class ScrollSyncCoordinator {
    /// The scroll view currently driving the shared offset.
    weak var activeScrollView: UIScrollView?

    /// Called when a scroll view is touched by the user.
    /// Stops any ongoing deceleration in the *other* scroll view.
    func claimLeadership(_ scrollView: UIScrollView) {
        if let previous = activeScrollView, previous !== scrollView {
            // Stop deceleration by setting contentOffset to current position.
            previous.setContentOffset(previous.contentOffset, animated: false)
        }
        activeScrollView = scrollView
    }
}

// MARK: - Synced Horizontal Scroll View

struct SyncedHorizontalScrollView<Content: View>: UIViewRepresentable {
    let showsHorizontalScrollIndicator: Bool
    let syncCoordinator: ScrollSyncCoordinator
    let externalOffset: CGFloat
    let onOffsetChange: (CGFloat) -> Void
    let content: AnyView

    init(
        showsHorizontalScrollIndicator: Bool = false,
        syncCoordinator: ScrollSyncCoordinator,
        externalOffset: CGFloat,
        onOffsetChange: @escaping (CGFloat) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.showsHorizontalScrollIndicator = showsHorizontalScrollIndicator
        self.syncCoordinator = syncCoordinator
        self.externalOffset = externalOffset
        self.onOffsetChange = onOffsetChange
        self.content = AnyView(content())
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onOffsetChange: onOffsetChange, syncCoordinator: syncCoordinator)
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
        context.coordinator.syncCoordinator = syncCoordinator
        context.coordinator.hostingController.rootView = content
        context.coordinator.hostingController.view.invalidateIntrinsicContentSize()

        // Only follow external offset when this scroll view is NOT the leader.
        let isLeader = syncCoordinator.activeScrollView === scrollView
        if !isLeader {
            let targetX = -externalOffset
            if abs(scrollView.contentOffset.x - targetX) > 0.5 {
                context.coordinator.isApplyingExternalOffset = true
                scrollView.contentOffset.x = targetX
                context.coordinator.isApplyingExternalOffset = false
            }
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var onOffsetChange: (CGFloat) -> Void
        var syncCoordinator: ScrollSyncCoordinator
        var isApplyingExternalOffset = false
        let hostingController = UIHostingController(rootView: AnyView(EmptyView()))

        init(onOffsetChange: @escaping (CGFloat) -> Void, syncCoordinator: ScrollSyncCoordinator) {
            self.onOffsetChange = onOffsetChange
            self.syncCoordinator = syncCoordinator
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard !isApplyingExternalOffset else { return }
            onOffsetChange(-scrollView.contentOffset.x)
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            syncCoordinator.claimLeadership(scrollView)
        }

        func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
            if !decelerate {
                clearLeadershipIfNeeded(scrollView)
            }
        }

        func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
            clearLeadershipIfNeeded(scrollView)
        }

        private func clearLeadershipIfNeeded(_ scrollView: UIScrollView) {
            if syncCoordinator.activeScrollView === scrollView {
                syncCoordinator.activeScrollView = nil
            }
        }
    }
}
#endif
