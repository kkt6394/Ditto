//
//  NodeRenderView.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import SwiftUI

// 단일 노드를 NodeContent에 따라 SwiftUI 뷰로 렌더링한다.
// .position/.rotationEffect/.scaleEffect는 호출 측(ActivityCardCanvasView)에서 적용.
struct NodeRenderView: View {
    let node: ActivityCardCanvasNode
    let snapshots: [ActivityMemorySnapshot]
    let isSelected: Bool

    var body: some View {
        contentView
            .overlay(selectionOutline)
    }

    @ViewBuilder
    private var contentView: some View {
        switch node.content {
        case .text(let text):
            UserTextNodeView(text: text)
        case .image(let image):
            UserImageNodeView(image: image)
        case .design(let kind, let orderIndex):
            if let snapshot = snapshots.indices.contains(orderIndex) ? snapshots[orderIndex] : nil {
                designView(for: kind, snapshot: snapshot)
            }
        case .memoCard(let text, let orderIndex):
            if let snapshot = snapshots.indices.contains(orderIndex) ? snapshots[orderIndex] : nil {
                // 정사각형 카드(240x240)에 사진(180x180)을 가운데 두면 위·아래에 한 줄씩만 들어간다.
                // TextKit `exclusionPaths`가 사진을 피해 위/아래에 텍스트를 흘려준다.
                TextKitMemoCardView(text: text, image: snapshot.activityImage)
                    .frame(width: 240, height: 240)
            }
        }
    }

    @ViewBuilder
    private var selectionOutline: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(MainScreenPalette.primaryBlue, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                .padding(-4)
        }
    }

    @ViewBuilder
    private func designView(for kind: DesignKind, snapshot: ActivityMemorySnapshot) -> some View {
        switch kind {
        case .brand, .sub, .bottomTitle, .underline:
            headerFooterView(for: kind)
        case .heroImage, .mainLabel, .dateBox, .guestsBox, .scheduleBox, .totalBox, .quote, .stamp:
            mainContentView(for: kind, snapshot: snapshot)
        default:
            decoView(for: kind)
        }
    }

    @ViewBuilder
    private func headerFooterView(for kind: DesignKind) -> some View {
        switch kind {
        case .brand: ActivityMemoryBrand()
        case .sub: ActivityMemorySub()
        case .bottomTitle: ActivityMemoryBottomTitle()
        case .underline: ActivityMemoryUnderline()
        default: EmptyView()
        }
    }

    @ViewBuilder
    private func mainContentView(
        for kind: DesignKind,
        snapshot: ActivityMemorySnapshot
    ) -> some View {
        switch kind {
        case .heroImage: ActivityMemoryHeroImage(image: snapshot.activityImage)
        case .mainLabel: ActivityMemoryMainLabel(snapshot: snapshot)
        case .dateBox: ActivityMemoryDateBox(snapshot: snapshot)
        case .guestsBox: ActivityMemoryGuestsBox(snapshot: snapshot)
        case .scheduleBox: ActivityMemoryScheduleBox(snapshot: snapshot)
        case .totalBox: ActivityMemoryTotalBox(snapshot: snapshot)
        case .quote: ActivityMemoryQuote()
        case .stamp: ActivityMemoryStamp()
        default: EmptyView()
        }
    }

    @ViewBuilder
    private func decoView(for kind: DesignKind) -> some View {
        switch kind {
        case .heart: ActivityMemoryHeartDeco()
        case .clip: ActivityMemoryClipDeco()
        case .star1: ActivityMemoryStarDeco(symbol: "✦", color: MemoryPalette.red)
        case .star2: ActivityMemoryStarDeco(symbol: "@", color: MemoryPalette.ink)
        case .hashSign: ActivityMemoryStarDeco(symbol: "#", color: MemoryPalette.ink)
        case .arrow1: ActivityMemoryArrowDeco(name: "arrow.down.right", size: CGSize(width: 90, height: 60))
        case .arrow2: ActivityMemoryArrowDeco(name: "arrow.up.right", size: CGSize(width: 82, height: 62))
        case .arrow3: ActivityMemoryArrowDeco(name: "arrow.right", size: CGSize(width: 118, height: 58))
        default: EmptyView()
        }
    }
}

// 사용자 추가 텍스트 노드 — 흰 배경 + 검은 테두리.
struct UserTextNodeView: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 22, weight: .heavy))
            .foregroundStyle(.black)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.white, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black.opacity(0.85), lineWidth: 2)
            )
    }
}

// 사용자 추가 이미지 노드 — 둥근 사각형 + 검은 테두리 + 그림자.
struct UserImageNodeView: View {
    let image: UIImage
    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: 160, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.black.opacity(0.85), lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.18), radius: 0, x: 4, y: 5)
    }
}
