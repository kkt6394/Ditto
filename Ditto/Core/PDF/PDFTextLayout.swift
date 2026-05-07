//
//  PDFTextLayout.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import Foundation
import UIKit

// TextKit(NSTextStorage + NSLayoutManager + NSTextContainer) 페이지 분할기.
// 긴 NSAttributedString을 페이지 단위로 자르며 PDFRenderContext에 그린다.
struct PDFTextLayout {
    let containerSize: CGSize
    let origin: CGPoint
    let onNewPage: ((PDFRenderContext) -> Void)?

    init(
        containerSize: CGSize,
        origin: CGPoint,
        onNewPage: ((PDFRenderContext) -> Void)? = nil
    ) {
        self.containerSize = containerSize
        self.origin = origin
        self.onNewPage = onNewPage
    }

    // attributedString을 컨테이너 크기에 맞춰 페이지로 흘려보낸다.
    // 첫 페이지는 호출 시점의 현재 페이지에 그리고,
    // 부족하면 newPage()로 다음 페이지로 넘어간다.
    func draw(_ attributedString: NSAttributedString, in ctx: PDFRenderContext) {
        guard attributedString.length > 0 else { return }

        let storage = NSTextStorage(attributedString: attributedString)
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)

        var glyphIndex = 0
        var isFirstPage = true

        // 모든 글리프가 다 그려질 때까지 컨테이너를 추가하며 페이지를 흘려보낸다.
        while glyphIndex < layout.numberOfGlyphs {
            let container = NSTextContainer(size: containerSize)
            container.lineFragmentPadding = 0
            layout.addTextContainer(container)

            let glyphRange = layout.glyphRange(for: container)
            if !isFirstPage {
                ctx.newPage()
                onNewPage?(ctx)
            }
            isFirstPage = false

            layout.drawGlyphs(forGlyphRange: glyphRange, at: origin)
            glyphIndex = NSMaxRange(glyphRange)
        }
    }

    // 미리 페이지 수를 세야 하는 케이스(푸터에 "1 / N" 표기)를 위한 dry-run.
    static func pageCount(for attributedString: NSAttributedString, containerSize: CGSize) -> Int {
        guard attributedString.length > 0 else { return 0 }
        let storage = NSTextStorage(attributedString: attributedString)
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)

        var glyphIndex = 0
        var pages = 0
        while glyphIndex < layout.numberOfGlyphs {
            let container = NSTextContainer(size: containerSize)
            container.lineFragmentPadding = 0
            layout.addTextContainer(container)
            let range = layout.glyphRange(for: container)
            pages += 1
            glyphIndex = NSMaxRange(range)
        }
        return pages
    }
}
