//
//  ActivityReportSnapshot.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import Foundation
import UIKit

// View ↔ Renderer 사이의 경계 값 객체.
// 렌더링이 백그라운드 Task에서 돌아도 안전하도록 값 타입으로 둔다.
// thumbnails는 orderId → 미리 다운로드된 액티비티 썸네일 매핑.
struct ActivityReportSnapshot {
    let userDisplayName: String
    let generatedAt: Date
    let scope: ActivityReportScope
    let stats: ActivityReportStats
    let orders: [OrderReviewResponseDTO]
    let thumbnails: [String: UIImage]
    let markupOverlay: UIImage?
}
