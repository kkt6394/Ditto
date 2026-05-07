//
//  PDFPreviewView.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import PDFKit
import SwiftUI
import UIKit

// 생성된 PDF를 화면에 미리 보여주는 단순 wrapper.
struct PDFPreviewView: UIViewRepresentable {
    let url: URL

    func makeUIView(context _: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .clear
        pdfView.document = PDFDocument(url: url)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context _: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
    }
}
