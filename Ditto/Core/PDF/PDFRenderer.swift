//
//  PDFRenderer.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import Foundation
import UIKit

// 페이지 단위 렌더 콜백을 받는 PDF 빌더.
// 사용자는 draw 클로저 안에서 한 페이지씩 그린다.
// 다음 페이지가 필요하면 newPage()로 넘긴다.
struct PDFRenderer {
    let pageSize: CGSize
    let metadata: [String: Any]

    init(pageSize: CGSize = PDFPaper.a4Size, metadata: [String: Any] = [:]) {
        self.pageSize = pageSize
        self.metadata = metadata
    }

    func render(to fileURL: URL, draw: (PDFRenderContext) -> Void) throws {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = metadata
        let bounds = CGRect(origin: .zero, size: pageSize)
        let renderer = UIGraphicsPDFRenderer(bounds: bounds, format: format)

        try renderer.writePDF(to: fileURL) { context in
            // 첫 페이지는 클로저 시작 시점에 자동으로 열린다.
            context.beginPage()
            let renderContext = PDFRenderContext(uiContext: context, pageSize: pageSize)
            draw(renderContext)
        }
    }
}

// 렌더 콜백에서 사용자가 다루는 컨텍스트. CGContext와 페이지 전환만 노출.
final class PDFRenderContext {
    let cgContext: CGContext
    let pageSize: CGSize
    private(set) var pageIndex: Int = 0

    private let uiContext: UIGraphicsPDFRendererContext

    init(uiContext: UIGraphicsPDFRendererContext, pageSize: CGSize) {
        self.uiContext = uiContext
        self.cgContext = uiContext.cgContext
        self.pageSize = pageSize
    }

    // 다음 페이지로 넘긴다. 첫 페이지는 이미 열려 있으므로 호출하지 않아도 된다.
    func newPage() {
        uiContext.beginPage()
        pageIndex += 1
    }

    var contentRect: CGRect {
        PDFPaper.contentRect(in: pageSize)
    }
}
