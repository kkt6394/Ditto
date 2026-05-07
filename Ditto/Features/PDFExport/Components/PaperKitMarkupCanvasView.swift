//
//  PaperKitMarkupCanvasView.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import PencilKit
import SwiftUI
import UIKit

// 표지 손글씨 / 영수증 사인을 받기 위한 캔버스.
// iOS 26 PaperKit `MarkupView`로 교체 가능한 구조로 두되, 정식 API 확인 전까지는
// PaperKit이 내부적으로 사용하는 PencilKit PKCanvasView로 동등한 경험을 제공한다.
// 외부에는 `image: Binding<UIImage?>`만 노출하므로 추후 swap이 단일 파일로 끝난다.
struct PaperKitMarkupCanvasView: UIViewRepresentable {
    @Binding var image: UIImage?

    func makeCoordinator() -> Coordinator {
        Coordinator(image: $image)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.drawingPolicy = .anyInput
        canvas.delegate = context.coordinator

        // 도구 선택기는 First responder가 되어야 떠서, 잠깐 첫 응답자로 만든다.
        if let window = canvas.window, let toolPicker = PKToolPicker.shared(for: window) {
            toolPicker.setVisible(true, forFirstResponder: canvas)
            toolPicker.addObserver(canvas)
            canvas.becomeFirstResponder()
        }
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context _: Context) {
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
            // 그릴 때마다 투명 배경 PNG로 캡쳐해두면 ViewModel은 markupImage만 보면 된다.
            let drawingBounds = canvasView.drawing.bounds
            guard !drawingBounds.isEmpty else {
                image.wrappedValue = nil
                return
            }
            let captured = canvasView.drawing.image(from: drawingBounds, scale: UIScreen.main.scale)
            image.wrappedValue = captured
        }
    }
}
