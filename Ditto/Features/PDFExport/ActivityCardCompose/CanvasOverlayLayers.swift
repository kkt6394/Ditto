//
//  CanvasOverlayLayers.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import SwiftUI

// 캔버스 위에 얹히는 layer들 — markup(손글씨)과 trash bin(쓰레기통)을 별도 파일로 분리.
// ActivityCardCanvasView의 file_length를 SwiftLint 한계 안으로 유지한다.

// 손글씨 레이어. draw 모드에서는 PencilKit canvas 활성, arrange/export에서는 캡쳐된 markupImage Image로 표시.
// ImageRenderer가 PencilKit UIView를 캡쳐하지 못해 export PNG에 placeholder("노란 바탕 빨강 금지")가
// 보이던 버그를 우회한다.
struct CanvasMarkupLayer: View {
    @Bindable var viewModel: ActivityCardCanvasViewModel
    let isExporting: Bool

    var body: some View {
        let canvas = ActivityMemoryCanvasView.canvasSize
        if !isExporting && viewModel.editorMode == .draw {
            PencilCanvasView(
                image: $viewModel.markupImage,
                inkColor: viewModel.currentInkColor,
                inkWidth: viewModel.inkWidth
            )
            .frame(width: canvas.width, height: canvas.height)
        } else if let markup = viewModel.markupImage {
            Image(uiImage: markup)
                .resizable()
                .scaledToFit()
                .frame(width: canvas.width, height: canvas.height)
                .allowsHitTesting(false)
        }
    }
}

// 캔버스 하단 중앙에 떠 있는 쓰레기통. 노드를 드래그해서 그 위에 두면 삭제된다.
// 드래그 중에만 표시되고 export PNG에는 들어가지 않는다.
struct CanvasTrashBin: View {
    let isHighlighted: Bool

    var body: some View {
        let rect = ActivityCardCanvasViewModel.trashRect
        return ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(isHighlighted ? Color.red.opacity(0.85) : Color.black.opacity(0.55))
            VStack(spacing: 4) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 24, weight: .bold))
                Text("여기로 드래그해서 삭제")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(.white)
        }
        .frame(width: rect.width, height: rect.height)
        .position(x: rect.midX, y: rect.midY)
        .allowsHitTesting(false)
    }
}
