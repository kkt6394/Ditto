//
//  TextKitMemoCardView.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import SwiftUI
import UIKit

// TextKit의 진가(`NSTextContainer.exclusionPaths`)를 살리는 회고 메모 카드.
// SwiftUI Canvas + withCGContext 안에서 NSLayoutManager.drawGlyphs를 호출 → SwiftUI ImageRenderer로 PNG export 시
// 정상 캡쳐된다 (UIViewRepresentable 우회). 사진을 가운데 두고 글자가 4방향으로 둘러싸며 흐른다.
struct TextKitMemoCardView: View {
    let text: String
    let image: UIImage?
    let cardSize: CGSize
    let imageRect: CGRect

    init(
        text: String,
        image: UIImage?,
        cardSize: CGSize = CGSize(width: 240, height: 240),
        imageRect: CGRect = CGRect(x: 30, y: 30, width: 180, height: 180)
    ) {
        self.text = text
        self.image = image
        self.cardSize = cardSize
        self.imageRect = imageRect
    }

    var body: some View {
        Canvas { context, _ in
            drawCardBackground(in: context)
            drawWrappedText(in: context)
            drawImage(in: context)
        }
        .frame(width: cardSize.width, height: cardSize.height)
    }

    private func drawCardBackground(in context: GraphicsContext) {
        let rect = CGRect(origin: .zero, size: cardSize)
        let cardPath = Path(roundedRect: rect, cornerRadius: 14)
        context.fill(cardPath, with: .color(.white))
        context.stroke(cardPath, with: .color(.black.opacity(0.85)), lineWidth: 2)
    }

    // 핵심: NSLayoutManager + NSTextContainer.exclusionPaths가 사진 영역을 피해 글자를 흘려준다.
    private func drawWrappedText(in context: GraphicsContext) {
        let inset: CGFloat = 12
        let textBounds = CGSize(
            width: cardSize.width - inset * 2,
            height: cardSize.height - inset * 2
        )
        // exclusion 사각형은 textContainer 좌표계(inset 적용 후)에서 정의된다.
        let exclusion = imageRect.offsetBy(dx: -inset, dy: -inset)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13, weight: .regular),
            .foregroundColor: UIColor.black
        ]
        let storage = NSTextStorage(string: text, attributes: attributes)
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: textBounds)
        container.lineFragmentPadding = 0
        container.exclusionPaths = [UIBezierPath(rect: exclusion)]
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)

        context.withCGContext { cgContext in
            cgContext.saveGState()
            UIGraphicsPushContext(cgContext)
            cgContext.translateBy(x: inset, y: inset)
            let glyphRange = layout.glyphRange(for: container)
            layout.drawGlyphs(forGlyphRange: glyphRange, at: .zero)
            UIGraphicsPopContext()
            cgContext.restoreGState()
        }
    }

    private func drawImage(in context: GraphicsContext) {
        guard let image else { return }
        // 둥근 사각형 안 aspect-fill로 사진을 잘라 그린다.
        let path = Path(roundedRect: imageRect, cornerRadius: 8)
        var clippedContext = context
        clippedContext.clip(to: path)
        let imageSize = image.size
        let scale = max(imageRect.width / imageSize.width, imageRect.height / imageSize.height)
        let scaled = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let drawRect = CGRect(
            x: imageRect.midX - scaled.width / 2,
            y: imageRect.midY - scaled.height / 2,
            width: scaled.width,
            height: scaled.height
        )
        clippedContext.draw(Image(uiImage: image), in: drawRect)
        // 둥근 사각형 외곽선.
        context.stroke(path, with: .color(.black.opacity(0.85)), lineWidth: 1.5)
    }
}
