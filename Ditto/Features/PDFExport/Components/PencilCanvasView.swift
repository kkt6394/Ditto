//
//  PencilCanvasView.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import PencilKit
import SwiftUI
import UIKit

// 손글씨 캔버스. PencilKit `PKCanvasView`를 SwiftUI `UIViewRepresentable`로 감싼 단순 wrapper.
// 외부에는 `image: Binding<UIImage?>`(그린 결과), `inkColor`, `inkWidth`만 노출.
struct PencilCanvasView: UIViewRepresentable {
    @Binding var image: UIImage?
    var inkColor: UIColor
    var inkWidth: CGFloat

    init(
        image: Binding<UIImage?>,
        inkColor: UIColor = .black,
        inkWidth: CGFloat = 4
    ) {
        self._image = image
        self.inkColor = inkColor
        self.inkWidth = inkWidth
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(image: $image)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.delegate = context.coordinator
        canvas.tool = PKInkingTool(.pen, color: inkColor, width: inkWidth)
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context _: Context) {
        // 잉크 색·굵기는 외부에서 바뀔 때마다 캔버스 tool에 반영.
        uiView.tool = PKInkingTool(.pen, color: inkColor, width: inkWidth)

        // 외부에서 image가 nil로 리셋되면 캔버스도 같이 비워준다.
        if image == nil && !uiView.drawing.bounds.isEmpty {
            uiView.drawing = PKDrawing()
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let image: Binding<UIImage?>

        init(image: Binding<UIImage?>) {
            self.image = image
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // 그릴 때마다 투명 배경 PNG로 캡쳐. SwiftUI render 사이클 충돌을 피해 다음 runloop으로 미룬다.
            let drawingBounds = canvasView.drawing.bounds
            let captured: UIImage? = drawingBounds.isEmpty
                ? nil
                : canvasView.drawing.image(from: drawingBounds, scale: UIScreen.main.scale)
            DispatchQueue.main.async { [image] in
                image.wrappedValue = captured
            }
        }
    }
}
