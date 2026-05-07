//
//  PDFPaper.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import SwiftUI
import UIKit

// PDF 출력 단위 토큰. A4 기본, 마진/색은 모든 렌더러가 공유한다.
enum PDFPaper {
    // 72dpi 기준 포인트. PDF 스펙은 1pt = 1/72 inch.
    static let a4Size = CGSize(width: 595.2, height: 841.8)
    static let letterSize = CGSize(width: 612.0, height: 792.0)

    static let margin = UIEdgeInsets(top: 56, left: 48, bottom: 64, right: 48)

    // 본문 영역 (페이지 - 마진).
    static func contentRect(in pageSize: CGSize) -> CGRect {
        CGRect(
            x: margin.left,
            y: margin.top,
            width: pageSize.width - margin.left - margin.right,
            height: pageSize.height - margin.top - margin.bottom
        )
    }
}

// SwiftUI Color → UIColor 변환을 PDF 렌더 쪽에서 일관되게 쓰려고 한 곳에 모아둔다.
enum PDFPalette {
    static let background = UIColor(MainScreenPalette.background)
    static let surface = UIColor(MainScreenPalette.surface)
    static let textPrimary = UIColor(MainScreenPalette.textPrimary)
    static let textSecondary = UIColor(MainScreenPalette.textSecondary)
    static let textMuted = UIColor(MainScreenPalette.textMuted)
    static let primaryBlue = UIColor(MainScreenPalette.primaryBlue)
    static let primaryBlueSoft = UIColor(MainScreenPalette.primaryBlueSoft)
    static let border = UIColor(MainScreenPalette.border)
}
