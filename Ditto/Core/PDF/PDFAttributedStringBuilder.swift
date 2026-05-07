//
//  PDFAttributedStringBuilder.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import Foundation
import UIKit

// PDF 본문에 쓸 NSAttributedString을 만들 때 폰트/단락 스타일 보일러플레이트를 줄이는 헬퍼.
enum PDFAttributedStringBuilder {
    enum Weight {
        case regular, medium, semibold, bold

        var fontName: String {
            switch self {
            case .regular: return "Pretendard-Regular"
            case .medium: return "Pretendard-Medium"
            case .semibold: return "Pretendard-SemiBold"
            case .bold: return "Pretendard-Bold"
            }
        }

        var systemWeight: UIFont.Weight {
            switch self {
            case .regular: return .regular
            case .medium: return .medium
            case .semibold: return .semibold
            case .bold: return .bold
            }
        }
    }

    // 등록된 커스텀 폰트가 없으면 system 폰트로 폴백한다.
    static func font(_ weight: Weight, size: CGFloat) -> UIFont {
        UIFont(name: weight.fontName, size: size)
            ?? UIFont.systemFont(ofSize: size, weight: weight.systemWeight)
    }

    static func paperlogy(size: CGFloat) -> UIFont {
        UIFont(name: "Paperlogy-9Black", size: size)
            ?? UIFont.systemFont(ofSize: size, weight: .black)
    }

    // 본문 한 단락. paragraphSpacingBefore/After로 카드 간 여백 확보.
    static func paragraph(
        _ text: String,
        font: UIFont,
        color: UIColor = PDFPalette.textPrimary,
        lineHeightMultiple: CGFloat = 1.25,
        spacingBefore: CGFloat = 0,
        spacingAfter: CGFloat = 0
    ) -> NSAttributedString {
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = lineHeightMultiple
        style.paragraphSpacingBefore = spacingBefore
        style.paragraphSpacing = spacingAfter

        return NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: style
            ]
        )
    }

    // 페이지 강제 분할용 form-feed 문자.
    static let pageBreak = NSAttributedString(string: "\u{0C}\n")
}
