import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension GradebookDetailView {
    // MARK: - Table Layout

    private var tableContent: some View {
        VStack(spacing: 0) {
            stickyTableHeaderRow
            scrollableTableBody
        }
        .contentShape(Rectangle())
        .overlay {
            Color.clear
                .contentShape(Rectangle())
                .allowsHitTesting(false)
        }
        #if !os(iOS)
        .onPreferenceChange(GridHorizontalContentOffsetPreferenceKey.self) { value in
            viewModel.horizontalScrollOffset = value
        }
        #endif
    }

    #if os(iOS)
    private var iOSTableZoomContainer: some View {
        TablePinchZoomContainer(
            onChanged: { magnification in
                viewModel.zoomScale = max(0.5, min(viewModel.baseZoomScale * magnification, 3.0))
            },
            onEnded: {
                viewModel.baseZoomScale = viewModel.zoomScale
            }
        ) {
            tableContent
        }
    }
    #endif

    @available(iOS 17.0, macOS 14.0, *)
    private var modernTableZoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                viewModel.zoomScale = max(0.5, min(viewModel.baseZoomScale * value.magnification, 3.0))
            }
            .onEnded { _ in
                viewModel.baseZoomScale = viewModel.zoomScale
            }
    }

    private var legacyTableZoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                viewModel.zoomScale = max(0.5, min(viewModel.baseZoomScale * value, 3.0))
            }
            .onEnded { _ in
                viewModel.baseZoomScale = viewModel.zoomScale
            }
    }

    private func scaledTableSection<Content: View>(
        baseWidth: CGFloat,
        baseHeight: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(width: baseWidth, height: baseHeight, alignment: .topLeading)
            .scaleEffect(viewModel.zoomScale, anchor: .topLeading)
            .frame(
                width: baseWidth * viewModel.zoomScale,
                height: baseHeight * viewModel.zoomScale,
                alignment: .topLeading
            )
    }

    @ViewBuilder
    private var stickyGridHeaderViewport: some View {
        #if os(iOS)
        SyncedHorizontalScrollView(
            showsHorizontalScrollIndicator: false,
            syncCoordinator: viewModel.scrollSyncCoordinator,
            externalOffset: viewModel.horizontalScrollOffset,
            onOffsetChange: { viewModel.horizontalScrollOffset = $0 }
        ) {
            scaledTableSection(
                baseWidth: totalColumnsWidth,
                baseHeight: headerHeight
            ) {
                gridHeaderView
            }
        }
        .frame(height: headerHeight * viewModel.zoomScale, alignment: .topLeading)
        #else
        GeometryReader { geometry in
            scaledTableSection(
                baseWidth: totalColumnsWidth,
                baseHeight: headerHeight
            ) {
                gridHeaderView
            }
            .offset(x: viewModel.horizontalScrollOffset)
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
            .clipped()
        }
        .frame(height: headerHeight * viewModel.zoomScale)
        #endif
    }

    private var stickyTableHeaderRow: some View {
        HStack(alignment: .top, spacing: 0) {
            scaledTableSection(
                baseWidth: nameColumnWidth,
                baseHeight: headerHeight
            ) {
                nameColumnHeader
            }

            stickyGridHeaderViewport
        }
    }

    @ViewBuilder
    private var horizontalGridRowsScrollView: some View {
        #if os(iOS)
        SyncedHorizontalScrollView(
            showsHorizontalScrollIndicator: false,
            syncCoordinator: viewModel.scrollSyncCoordinator,
            externalOffset: viewModel.horizontalScrollOffset,
            onOffsetChange: { viewModel.horizontalScrollOffset = $0 }
        ) {
            scaledTableSection(
                baseWidth: totalColumnsWidth,
                baseHeight: gridRowsHeight
            ) {
                gridRowsView
            }
        }
        .frame(height: gridRowsHeight * viewModel.zoomScale, alignment: .topLeading)
        #else
        ScrollView(.horizontal) {
            scaledTableSection(
                baseWidth: totalColumnsWidth,
                baseHeight: gridRowsHeight
            ) {
                gridRowsView
            }
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: GridHorizontalContentOffsetPreferenceKey.self,
                        value: geometry.frame(in: .named("gradebookHorizontalScroll")).minX
                    )
                }
            }
        }
        .coordinateSpace(name: "gradebookHorizontalScroll")
        .frame(height: gridRowsHeight * viewModel.zoomScale, alignment: .topLeading)
        #endif
    }

    private var scrollableTableBody: some View {
        ScrollView(.vertical) {
            HStack(alignment: .top, spacing: 0) {
                scaledTableSection(
                    baseWidth: nameColumnWidth,
                    baseHeight: nameColumnRowsHeight
                ) {
                    nameColumnRows
                }

                horizontalGridRowsScrollView
            }
            .contentShape(Rectangle())
        }
    }

    @available(iOS 17.0, macOS 14.0, *)
    var modernZoomableTableLayout: some View {
        #if os(iOS)
        iOSTableZoomContainer
        #else
        tableContent
            .highPriorityGesture(modernTableZoomGesture, including: .subviews)
        #endif
    }

    var legacyZoomableTableLayout: some View {
        #if os(iOS)
        iOSTableZoomContainer
        #else
        tableContent
            .highPriorityGesture(legacyTableZoomGesture, including: .subviews)
        #endif
    }

    @ViewBuilder
    var zoomableTableLayout: some View {
        if #available(iOS 17.0, macOS 14.0, *) {
            modernZoomableTableLayout
        } else {
            legacyZoomableTableLayout
        }
    }


}
#if os(iOS)
private struct TablePinchZoomContainer<Content: View>: UIViewControllerRepresentable {
    let onChanged: (CGFloat) -> Void
    let onEnded: () -> Void
    let content: Content

    init(
        onChanged: @escaping (CGFloat) -> Void,
        onEnded: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.onChanged = onChanged
        self.onEnded = onEnded
        self.content = content()
    }

    func makeUIViewController(context: Context) -> ContainerViewController<Content> {
        let controller = ContainerViewController(rootView: content)
        controller.coordinator = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: ContainerViewController<Content>, context: Context) {
        context.coordinator.onChanged = onChanged
        context.coordinator.onEnded = onEnded
        uiViewController.coordinator = context.coordinator
        uiViewController.update(rootView: content)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChanged: onChanged, onEnded: onEnded)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChanged: (CGFloat) -> Void
        var onEnded: () -> Void

        lazy var pinchRecognizer: UIPinchGestureRecognizer = {
            let recognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
            recognizer.delegate = self
            recognizer.cancelsTouchesInView = false
            return recognizer
        }()

        init(onChanged: @escaping (CGFloat) -> Void, onEnded: @escaping () -> Void) {
            self.onChanged = onChanged
            self.onEnded = onEnded
        }

        @objc
        private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .began, .changed:
                onChanged(recognizer.scale)
            case .ended, .cancelled, .failed:
                onEnded()
            default:
                break
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            true
        }
    }

    final class ContainerViewController<Root: View>: UIViewController {
        private let hostingController: UIHostingController<Root>
        var coordinator: Coordinator? {
            didSet {
                guard let coordinator else { return }
                if !(view.gestureRecognizers?.contains(coordinator.pinchRecognizer) ?? false) {
                    view.addGestureRecognizer(coordinator.pinchRecognizer)
                }
            }
        }

        init(rootView: Root) {
            self.hostingController = UIHostingController(rootView: rootView)
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .clear
            hostingController.view.backgroundColor = .clear
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false

            addChild(hostingController)
            view.addSubview(hostingController.view)
            NSLayoutConstraint.activate([
                hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            hostingController.didMove(toParent: self)
        }

        func update(rootView: Root) {
            hostingController.rootView = rootView
        }
    }
}
#endif

