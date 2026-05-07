//
//  ActivityCardCanvasView.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import PhotosUI
import SwiftUI

// 액티비티 카드 만들기 — 통합 캔버스 v7.
// 모든 노드(디자인·텍스트·이미지)를 단일 ForEach로 렌더링.
// 노드를 탭하면 array 끝으로 이동해 ZStack에서 위로 떠오른다(z-order 자동).
struct ActivityCardCanvasView: View {
    let orders: [OrderReviewResponseDTO]
    let authManager: any AuthManaging

    @Environment(\.dismiss) private var dismiss
    @Environment(\.imageLoader) private var imageLoader
    @State private var viewModel: ActivityCardCanvasViewModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var isPresentingTextAlert = false
    @State private var textInput = ""
    @State private var isPresentingMemoAlert = false
    @State private var memoInput = ""
    @State private var dragStart: [UUID: CGPoint] = [:]
    @State private var scaleStart: [UUID: CGFloat] = [:]
    @State private var rotationStart: [UUID: Double] = [:]
    @State private var draggingNodeId: UUID?
    @State private var isOverTrash = false
    @State private var isPresentingDesignPicker = false

    init(orders: [OrderReviewResponseDTO], authManager: any AuthManaging) {
        self.orders = orders
        self.authManager = authManager
        let configuration = try? AppConfiguration()
        let accessToken = authManager.tokens?.accessToken
        let builder: (String) -> URLRequest? = { path in
            guard let configuration else { return nil }
            return ActivityFormatting.makeImageRequest(
                from: path,
                configuration: configuration,
                accessToken: accessToken
            )
        }
        _viewModel = State(initialValue: ActivityCardCanvasViewModel(
            orders: orders,
            imageRequestBuilder: builder
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            ActivityCardCanvasNavBar(
                title: navigationTitle,
                onClose: navBarClose,
                showsClose: !isExportedPhase
            ) {
                trailingButton
            }
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MainScreenPalette.background.ignoresSafeArea())
        .task {
            viewModel.imageLoader = imageLoader
            await viewModel.bootstrap()
        }
        .alert("텍스트 추가", isPresented: $isPresentingTextAlert) {
            TextField("내용", text: $textInput)
            Button("추가") {
                viewModel.addTextNode(textInput)
                textInput = ""
            }
            Button("취소", role: .cancel) { textInput = "" }
        }
        .alert("회고 메모", isPresented: $isPresentingMemoAlert) {
            TextField("사진 옆에 흐를 회고 텍스트", text: $memoInput, axis: .vertical)
            Button("추가") {
                viewModel.addMemoCard(text: memoInput, orderIndex: 0)
                memoInput = ""
            }
            Button("취소", role: .cancel) { memoInput = "" }
        } message: {
            Text("TextKit이 사진 영역을 피해 글자를 흘려줍니다.")
        }
        .onChange(of: pickerItem) { _, newValue in
            Task { await loadPickedImage(from: newValue) }
        }
        .sheet(isPresented: $isPresentingDesignPicker) {
            DesignKindPickerView(snapshots: viewModel.snapshots) { kind, orderIndex in
                viewModel.addDesignNode(kind: kind, orderIndex: orderIndex)
            }
        }
    }
}

// MARK: - 상단 (타이틀 / 콘텐츠 분기 / 트레일링)

extension ActivityCardCanvasView {
    var navigationTitle: String {
        switch viewModel.phase {
        case .loadingImage: return "사진 준비 중"
        case .ready: return viewModel.editorMode == .draw ? "손글씨 모드" : "액티비티 카드"
        case .rendering: return "이미지 만드는 중"
        case .exported: return "완성"
        case .failed: return "오류"
        }
    }

    var isExportedPhase: Bool {
        if case .exported = viewModel.phase { return true }
        return false
    }

    func navBarClose() {
        // 완성 화면에서는 X 버튼이 사라지므로 호출되지 않지만, 다른 phase에서 dismiss.
        dismiss()
    }

    @ViewBuilder
    var content: some View {
        switch viewModel.phase {
        case .loadingImage, .rendering:
            loadingSection
        case .ready:
            readySection
        case .exported(let url, let image):
            exportedSection(url: url, image: image)
        case .failed(let message):
            failedSection(message: message)
        }
    }

    @ViewBuilder
    var trailingButton: some View {
        if case .ready = viewModel.phase, viewModel.markupImage != nil {
            Button {
                viewModel.markupImage = nil
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(width: 44, height: 44)
        }
    }
}

// MARK: - 섹션

extension ActivityCardCanvasView {
    var loadingSection: some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large)
            Text("잠깐만 기다려주세요.")
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    var readySection: some View {
        if let snapshot = viewModel.snapshot {
            VStack(spacing: 12) {
                editorToolbar
                if viewModel.editorMode == .draw {
                    inkPalette
                }
                canvasArea(snapshot: snapshot)
                exportButton(snapshot: snapshot)
            }
        }
    }

    func exportedSection(url: URL, image: UIImage) -> some View {
        let item = PDFShareItem(
            url: url,
            title: "Ditto 액티비티 카드",
            subtitle: orders.first?.activity.title ?? ""
        )
        return VStack(spacing: 12) {
            ScrollView(showsIndicators: false) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 12)
            }
            .background(MainScreenPalette.surface)
            exportedActions(item: item)
        }
    }

    private func exportedActions(item: PDFShareItem) -> some View {
        HStack(spacing: 12) {
            Button {
                viewModel.resetToReady()
            } label: {
                Text("계속 편집")
                    .font(MainFont.pretendard(.bold, size: 16))
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        MainScreenPalette.primaryBlueSoft,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
            }
            .buttonStyle(.plain)

            ShareLink(item: item, preview: item.sharePreview) {
                Text("공유 / 저장")
                    .font(MainFont.pretendard(.bold, size: 16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        MainScreenPalette.primaryBlue,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    func failedSection(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(MainScreenPalette.textSecondary)
            Text(message)
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 툴바 / 잉크 / 힌트

extension ActivityCardCanvasView {
    var editorToolbar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ToolbarChip(systemImage: "textformat", label: "텍스트", isActive: false) {
                    isPresentingTextAlert = true
                }
                ToolbarChip(systemImage: "doc.text", label: "회고 메모", isActive: false) {
                    isPresentingMemoAlert = true
                }
                PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                    ToolbarChipLabel(systemImage: "photo.badge.plus", label: "이미지", isActive: false)
                }
                ToolbarChip(systemImage: "rectangle.stack.badge.plus", label: "기본 객체", isActive: false) {
                    isPresentingDesignPicker = true
                }
                ToolbarChip(
                    systemImage: viewModel.editorMode == .draw ? "pencil.tip.crop.circle.fill" : "pencil.tip",
                    label: "그리기",
                    isActive: viewModel.editorMode == .draw
                ) {
                    viewModel.toggleMode()
                    viewModel.clearSelection()
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
    }

    var inkPalette: some View {
        ActivityCardCanvasInkPalette(viewModel: viewModel)
    }

    var hint: some View {
        Text("탭=선택, 드래그=이동(쓰레기통으로 드래그=삭제), 두 손가락=확대/회전")
            .font(MainScreenTypography.bodyCompact)
            .foregroundStyle(MainScreenPalette.textMuted)
            .padding(.horizontal, 16)
    }
}

// MARK: - 캔버스 합성 (단일 ForEach)

extension ActivityCardCanvasView {
    func canvasArea(snapshot: ActivityMemorySnapshot) -> some View {
        GeometryReader { proxy in
            let scale = canvasScale(for: proxy.size)
            canvasComposite(snapshot: snapshot)
                .frame(
                    width: ActivityMemoryCanvasView.canvasSize.width,
                    height: ActivityMemoryCanvasView.canvasSize.height
                )
                .scaleEffect(scale, anchor: .center)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .background(Color.white)
        }
        .padding(.horizontal, 12)
    }

    func canvasComposite(snapshot _: ActivityMemorySnapshot, isExporting: Bool = false) -> some View {
        ZStack {
            ActivityMemoryCanvasView()

            // 빈 공간 탭 → 선택 해제.
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { viewModel.clearSelection() }
                .frame(
                    width: ActivityMemoryCanvasView.canvasSize.width,
                    height: ActivityMemoryCanvasView.canvasSize.height
                )

            ForEach(viewModel.nodes) { node in
                nodeLayer(node: node)
            }

            CanvasMarkupLayer(viewModel: viewModel, isExporting: isExporting)

            // 쓰레기통은 드래그 중에만 표시. export 시에는 안 보임.
            if !isExporting && draggingNodeId != nil {
                CanvasTrashBin(isHighlighted: isOverTrash)
            }
        }
        // 캔버스 좌표 공간 등록 — DragGesture가 .named("canvas")로 손가락 위치를 캔버스 좌표로 받게 한다.
        .coordinateSpace(name: "canvas")
        // 노드를 확대해도 캔버스 frame 밖으로 나가지 않게 잘라낸다.
        .frame(
            width: ActivityMemoryCanvasView.canvasSize.width,
            height: ActivityMemoryCanvasView.canvasSize.height
        )
        .clipped()
    }
}

// MARK: - 노드 layer / 제스처 / 삭제

extension ActivityCardCanvasView {
    func nodeLayer(node: ActivityCardCanvasNode) -> some View {
        NodeRenderView(
            node: node,
            snapshots: viewModel.snapshots,
            isSelected: viewModel.selectedNodeId == node.id
        )
        .scaleEffect(node.scale)
        .rotationEffect(.degrees(node.rotation))
        .position(node.position)
        .gesture(nodeGesture(for: node))
        .onTapGesture { viewModel.selectAndBringToFront(node.id) }
        .allowsHitTesting(viewModel.editorMode == .arrange)
    }

    func nodeGesture(for node: ActivityCardCanvasNode) -> some Gesture {
        SimultaneousGesture(
            dragGesture(for: node),
            SimultaneousGesture(pinchGesture(for: node), rotationGesture(for: node))
        )
    }

    // 손가락 위치를 캔버스 좌표(.named("canvas"))로 받아 trash 충돌을 체크.
    // dragStart가 다른 노드에 잡혀있으면(이미 다른 노드 drag 중) 무시 — 한 번에 한 노드만 이동.
    func dragGesture(for node: ActivityCardCanvasNode) -> some Gesture {
        DragGesture(coordinateSpace: .named("canvas"))
            .onChanged { value in
                guard viewModel.editorMode == .arrange else { return }
                if let activeId = draggingNodeId, activeId != node.id {
                    return
                }
                if dragStart[node.id] == nil {
                    dragStart[node.id] = node.position
                    viewModel.selectAndBringToFront(node.id)
                    draggingNodeId = node.id
                }
                let start = dragStart[node.id] ?? node.position
                let candidate = CGPoint(
                    x: start.x + value.translation.width,
                    y: start.y + value.translation.height
                )
                viewModel.updatePosition(of: node.id, to: candidate)
                // 손가락의 캔버스 좌표 위치로 trash 충돌. 노드 center가 아니라 사용자가 보는 손가락 기준.
                isOverTrash = viewModel.isPositionInTrash(value.location)
            }
            .onEnded { _ in
                dragStart[node.id] = nil
                if draggingNodeId == node.id, isOverTrash {
                    viewModel.removeNode(node.id)
                }
                draggingNodeId = nil
                isOverTrash = false
            }
    }

    func pinchGesture(for node: ActivityCardCanvasNode) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                guard viewModel.editorMode == .arrange else { return }
                if scaleStart[node.id] == nil {
                    scaleStart[node.id] = node.scale
                    viewModel.selectAndBringToFront(node.id)
                }
                let baseline = scaleStart[node.id] ?? node.scale
                viewModel.updateScale(of: node.id, to: baseline * value)
            }
            .onEnded { _ in scaleStart[node.id] = nil }
    }

    func rotationGesture(for node: ActivityCardCanvasNode) -> some Gesture {
        RotationGesture()
            .onChanged { value in
                guard viewModel.editorMode == .arrange else { return }
                if rotationStart[node.id] == nil {
                    rotationStart[node.id] = node.rotation
                    viewModel.selectAndBringToFront(node.id)
                }
                let baseline = rotationStart[node.id] ?? node.rotation
                viewModel.updateRotation(of: node.id, to: baseline + value.degrees)
            }
            .onEnded { _ in rotationStart[node.id] = nil }
    }
}

// MARK: - Export 버튼 / 헬퍼

extension ActivityCardCanvasView {
    func exportButton(snapshot: ActivityMemorySnapshot) -> some View {
        Button {
            viewModel.clearSelection()
            // export 캔버스는 isExporting=true로 — PencilKit canvas 대신 markupImage Image 표시 + trash 숨김.
            viewModel.exportImage(canvas: canvasComposite(snapshot: snapshot, isExporting: true))
        } label: {
            Text("이미지로 저장")
                .font(MainFont.pretendard(.bold, size: 16))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    MainScreenPalette.primaryBlue,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    func canvasScale(for size: CGSize) -> CGFloat {
        let canvasSize = ActivityMemoryCanvasView.canvasSize
        let widthRatio = size.width / canvasSize.width
        let heightRatio = size.height / canvasSize.height
        return min(widthRatio, heightRatio, 1)
    }

    func loadPickedImage(from item: PhotosPickerItem?) async {
        defer { pickerItem = nil }
        guard let item else { return }
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            viewModel.addImageNode(image)
        }
    }
}

// 툴바 칩과 네비바는 ActivityCardCanvasChrome.swift로 분리됨.
