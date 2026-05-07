//
//  ReceiptPDFSnapshot.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import Foundation
import UIKit

// 단건 액티비티 PDF 렌더 입력. v2부터 결제 메타(영수증) 컨셉을 폐기하고
// 액티비티 이미지 + 메타를 한 페이지에 멋있게 보여주는 "추억 페이지"로 의미를 바꿨다.
struct ReceiptPDFSnapshot {
    let activityTitle: String
    let category: String?
    let totalPrice: Int
    let paidAt: String
    let activityImage: UIImage?
    let signatureOverlay: UIImage?
}
