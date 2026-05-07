//
//  PDFShareItem.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import CoreTransferable
import Foundation
import SwiftUI

// ShareLink가 미리보기에 쓸 PDF 메타. URL은 임시 폴더에 미리 생성되어 있어야 한다.
struct PDFShareItem: Transferable {
    let url: URL
    let title: String
    let subtitle: String?

    static var transferRepresentation: some TransferRepresentation {
        // 시스템이 PDF 파일로 인식하도록 URL 자체를 전달.
        ProxyRepresentation { (item: PDFShareItem) in item.url }
    }
}

extension PDFShareItem {
    var sharePreview: SharePreview<Image, Never> {
        SharePreview(title, image: Image(systemName: "doc.richtext"))
    }
}
