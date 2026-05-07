//
//  ActivityCardCanvasViewModel.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import Foundation
import Observation
import SwiftUI
import UIKit

// 액티비티 카드 만들기 — 캔버스/Export ViewModel.
// 진입 시 첫 번째 액티비티 thumbnail을 다운로드하고, 사용자가 텍스트·이미지 노드 추가와
// 손글씨를 그린 뒤 ImageRenderer로 캔버스 ZStack 통째로 PNG로 굽는다.
@MainActor
@Observable
final class ActivityCardCanvasViewModel {
    enum Phase: Equatable {
        case loadingImage
        case ready
        case rendering
        case exported(URL, UIImage)
        case failed(String)
    }

    enum EditorMode: Equatable {
        case arrange   // 노드 드래그/추가 가능, 손글씨 비활성
        case draw      // 손글씨 활성, 노드 드래그 비활성
    }

    private(set) var phase: Phase = .loadingImage
    var markupImage: UIImage?
    var nodes: [ActivityCardCanvasNode] = []
    var editorMode: EditorMode = .arrange

    // 손글씨 잉크 색/굵기. 사용자가 색 팔레트에서 선택해 PencilKit tool에 반영.
    var inkColorIndex: Int = 0
    var inkWidth: CGFloat = 4
    static let inkPalette: [UIColor] = [
        .black,
        UIColor(red: 1, green: 0.42, blue: 0.42, alpha: 1),  // red
        UIColor(red: 0.27, green: 0.55, blue: 0.96, alpha: 1),  // blue
        UIColor(red: 0.30, green: 0.78, blue: 0.47, alpha: 1),  // green
        UIColor(red: 1, green: 0.80, blue: 0.16, alpha: 1),     // yellow
        UIColor(red: 0.96, green: 0.46, blue: 0.78, alpha: 1),  // pink
        UIColor(red: 0.55, green: 0.40, blue: 0.92, alpha: 1),  // purple
        UIColor(red: 0.96, green: 0.61, blue: 0.20, alpha: 1)   // orange
    ]
    var currentInkColor: UIColor {
        let palette = ActivityCardCanvasViewModel.inkPalette
        let index = max(0, min(inkColorIndex, palette.count - 1))
        return palette[index]
    }

    // 모든 노드(디자인·텍스트·이미지)가 단일 시스템. 선택된 노드는 ID 하나로 추적.
    var selectedNodeId: UUID?

    private let orders: [OrderReviewResponseDTO]
    private let imageRequestBuilder: (String) -> URLRequest?

    var imageLoader: (any AuthenticatedImageLoading)?
    // 다중 액티비티 시 각 액티비티별 snapshot. 단일 호환을 위해 snapshot computed property도 노출.
    private(set) var snapshots: [ActivityMemorySnapshot] = []
    var snapshot: ActivityMemorySnapshot? { snapshots.first }

    init(
        orders: [OrderReviewResponseDTO],
        imageRequestBuilder: @escaping (String) -> URLRequest?
    ) {
        self.orders = orders
        self.imageRequestBuilder = imageRequestBuilder
    }

    func bootstrap() async {
        guard !orders.isEmpty else {
            phase = .failed("선택된 액티비티가 없습니다.")
            return
        }
        // 모든 액티비티의 thumbnail을 병렬로 다운로드. sequential 시 두 번째 이후 실패하던 문제를 피하면서 속도도 빠르다.
        let images = await loadAllImages(orders: orders)
        // 그 다음 snapshot 배열을 같은 순서로 구성.
        var loaded: [ActivityMemorySnapshot] = []
        for (index, order) in orders.enumerated() {
            let activityImage = images[index]
            // 디버그용 — 어떤 액티비티의 image가 nil로 들어왔는지 콘솔로 확인 가능.
            print(
                "[ActivityCardCanvasViewModel] order #\(index) "
                + "thumbnail=\(order.activity.thumbnails.first ?? "nil") "
                + "image=\(activityImage == nil ? "FAILED" : "OK")"
            )
            loaded.append(ActivityMemorySnapshot(
                activityTitle: order.activity.title ?? "이름 없는 액티비티",
                category: order.activity.category,
                totalPrice: order.totalPrice,
                paidAt: order.paidAt,
                participantCount: order.participantCount,
                scheduleLines: [
                    order.reservationItemName,
                    "일정 \(order.reservationItemTime)"
                ],
                activityImage: activityImage,
                signatureOverlay: nil
            ))
        }
        snapshots = loaded
        guard let primary = snapshots.first else {
            phase = .failed("선택된 액티비티 데이터를 만들지 못했습니다.")
            return
        }
        // 디자인 노드 21개를 첫 액티비티(index 0) 데이터로 채움. 사용자가 추가 메뉴에서 다른 액티비티 index로도 만들 수 있다.
        _ = primary  // bootstrap 보호 — snapshots 비어있으면 위에서 return.
        nodes = DesignKind.allCases.map { kind in
            ActivityCardCanvasNode(
                content: .design(kind: kind, orderIndex: 0),
                position: kind.defaultPosition,
                rotation: kind.defaultRotation,
                scale: 1
            )
        }
        phase = .ready
    }

    // 사용자가 "기본 객체 추가" 시트에서 디자인 종류 + 액티비티(orderIndex)를 골라 호출.
    func addDesignNode(kind: DesignKind, orderIndex: Int) {
        guard orderIndex >= 0, orderIndex < snapshots.count else { return }
        let new = ActivityCardCanvasNode(
            content: .design(kind: kind, orderIndex: orderIndex),
            position: kind.defaultPosition,
            rotation: kind.defaultRotation
        )
        nodes.append(new)
        selectAndBringToFront(new.id)
    }

    // TextKit exclusionPaths를 활용한 회고 메모 카드 추가.
    // 처음 등장할 때 캔버스 정 중앙에 두어 회고가 가장 눈에 띄게 한다 (다른 노드의 누적 offset 영향 X).
    func addMemoCard(text: String, orderIndex: Int) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let safeIndex = max(0, min(orderIndex, snapshots.count - 1))
        let canvas = ActivityMemoryCanvasView.canvasSize
        let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
        let new = ActivityCardCanvasNode(
            content: .memoCard(text: trimmed, orderIndex: safeIndex),
            position: center
        )
        nodes.append(new)
        selectAndBringToFront(new.id)
    }

    // MARK: - 노드 조작

    func addTextNode(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let new = ActivityCardCanvasNode(
            content: .text(trimmed),
            position: defaultDropPoint()
        )
        nodes.append(new)
        selectAndBringToFront(new.id)
    }

    func addImageNode(_ image: UIImage) {
        let new = ActivityCardCanvasNode(
            content: .image(image),
            position: defaultDropPoint()
        )
        nodes.append(new)
        selectAndBringToFront(new.id)
    }

    func updatePosition(of nodeId: UUID, to position: CGPoint) {
        guard let index = nodes.firstIndex(where: { $0.id == nodeId }) else { return }
        // 노드 center가 캔버스 영역(595x842) 안에 머물도록 클램프. 사용자가 자유롭게 드래그해도 화면 밖으로 사라지지 않는다.
        let canvas = ActivityMemoryCanvasView.canvasSize
        nodes[index].position = CGPoint(
            x: max(0, min(position.x, canvas.width)),
            y: max(0, min(position.y, canvas.height))
        )
    }

    // 노드가 쓰레기통 영역(캔버스 좌표계에서 하단 중앙) 안에 들어왔는지.
    static let trashRect = CGRect(
        x: ActivityMemoryCanvasView.canvasSize.width / 2 - 60,
        y: ActivityMemoryCanvasView.canvasSize.height - 90,
        width: 120,
        height: 80
    )

    func isPositionInTrash(_ position: CGPoint) -> Bool {
        ActivityCardCanvasViewModel.trashRect.contains(position)
    }

    func updateScale(of nodeId: UUID, to scale: CGFloat) {
        guard let index = nodes.firstIndex(where: { $0.id == nodeId }) else { return }
        nodes[index].scale = max(0.3, min(scale, 5))
    }

    func updateRotation(of nodeId: UUID, to rotation: Double) {
        guard let index = nodes.firstIndex(where: { $0.id == nodeId }) else { return }
        nodes[index].rotation = rotation
    }

    func removeNode(_ nodeId: UUID) {
        nodes.removeAll { $0.id == nodeId }
        if selectedNodeId == nodeId { selectedNodeId = nil }
    }

    // 선택과 동시에 nodes 배열의 끝으로 이동 → ZStack에서 자동으로 가장 위로 떠오른다.
    // 사용자 추가 노드든 디자인 노드든 동일하게 적용 — 마지막에 만진 객체가 항상 위.
    func selectAndBringToFront(_ id: UUID) {
        selectedNodeId = id
        guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
        let node = nodes.remove(at: index)
        nodes.append(node)
    }

    func clearSelection() {
        selectedNodeId = nil
    }

    func toggleMode() {
        editorMode = (editorMode == .arrange) ? .draw : .arrange
    }

    func selectInkColor(_ index: Int) {
        let count = ActivityCardCanvasViewModel.inkPalette.count
        inkColorIndex = max(0, min(index, count - 1))
    }

    private func defaultDropPoint() -> CGPoint {
        // 새 노드는 캔버스 중앙에서 살짝 흩어지게 배치 — 같은 위치 중첩 방지.
        let canvas = ActivityMemoryCanvasView.canvasSize
        let offset = CGFloat(nodes.count) * 16
        return CGPoint(x: canvas.width / 2 + offset, y: canvas.height / 2 + offset)
    }

    // MARK: - Export

    func exportImage<Content: View>(canvas: Content) {
        phase = .rendering
        let renderer = ImageRenderer(content: canvas)
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(ActivityMemoryCanvasView.canvasSize)

        guard let uiImage = renderer.uiImage,
              let pngData = uiImage.pngData() else {
            phase = .failed("이미지를 만들지 못했습니다.")
            return
        }

        do {
            let directory = try PDFFileNaming.temporaryDirectory()
            let fileName = PDFFileNaming.activityMemoryPNG(
                orderCode: orders.first?.orderCode ?? UUID().uuidString
            )
            let fileURL = directory.appendingPathComponent(fileName)
            try pngData.write(to: fileURL)
            phase = .exported(fileURL, uiImage)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func resetToReady() {
        phase = .ready
    }

    // MARK: - 이미지 다운로드

    private func loadImage(for order: OrderReviewResponseDTO) async -> UIImage? {
        guard let path = order.activity.thumbnails.first,
              let baseRequest = imageRequestBuilder(path) else {
            print("[ActivityCardCanvasViewModel] loadImage: no thumbnail/request for orderId=\(order.orderId)")
            return nil
        }
        // 외부 호스팅 이미지(절대 URL)는 SeSAC 인증 헤더를 거부하는 경우가 많아, 절대 URL이면 헤더를 떼고 보낸다.
        var request = baseRequest
        if URL(string: path)?.scheme != nil {
            request.setValue(nil, forHTTPHeaderField: "SeSACKey")
            request.setValue(nil, forHTTPHeaderField: "Authorization")
            print(
                "[ActivityCardCanvasViewModel] using bare request (absolute URL) "
                + "orderId=\(order.orderId) url=\(path)"
            )
        }
        let target = CGSize(width: 600, height: 400)
        do {
            return try await RemoteImageLoader.load(request: request, pointSize: target)
        } catch {
            print(
                "[ActivityCardCanvasViewModel] loadImage failed orderId=\(order.orderId) "
                + "thumbnailPath=\(path) error=\(error)"
            )
            return nil
        }
    }

    // 액티비티 thumbnail을 병렬로 동시 다운로드. 결과는 입력 orders와 같은 인덱스로 정렬해 반환.
    private func loadAllImages(orders: [OrderReviewResponseDTO]) async -> [Int: UIImage] {
        await withTaskGroup(of: (Int, UIImage?).self) { group in
            for (index, order) in orders.enumerated() {
                group.addTask {
                    let image = await self.loadImage(for: order)
                    return (index, image)
                }
            }
            var collected: [Int: UIImage] = [:]
            for await (index, image) in group {
                if let image {
                    collected[index] = image
                }
            }
            return collected
        }
    }
}
