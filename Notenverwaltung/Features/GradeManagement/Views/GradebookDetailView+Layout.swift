import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension GradebookDetailView {
    // MARK: - Table Layout

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

    private var stickyGridHeaderViewport: some View {
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
        VStack(spacing: 0) {
            stickyTableHeaderRow
            scrollableTableBody
        }
        #if !os(iOS)
        .onPreferenceChange(GridHorizontalContentOffsetPreferenceKey.self) { value in
            viewModel.horizontalScrollOffset = value
        }
        #endif
        .simultaneousGesture(
            MagnifyGesture()
                .onChanged { value in
                    viewModel.zoomScale = max(0.5, min(viewModel.baseZoomScale * value.magnification, 3.0))
                }
                .onEnded { _ in
                    viewModel.baseZoomScale = viewModel.zoomScale
                }
        )
    }

    var legacyZoomableTableLayout: some View {
        VStack(spacing: 0) {
            stickyTableHeaderRow
            scrollableTableBody
        }
        #if !os(iOS)
        .onPreferenceChange(GridHorizontalContentOffsetPreferenceKey.self) { value in
            viewModel.horizontalScrollOffset = value
        }
        #endif
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    viewModel.zoomScale = max(0.5, min(viewModel.baseZoomScale * value, 3.0))
                }
                .onEnded { _ in
                    viewModel.baseZoomScale = viewModel.zoomScale
                }
        )
    }

    var zoomableTableLayout: AnyView {
        if #available(iOS 17.0, macOS 14.0, *) {
            return AnyView(modernZoomableTableLayout)
        } else {
            return AnyView(legacyZoomableTableLayout)
        }
    }


}
