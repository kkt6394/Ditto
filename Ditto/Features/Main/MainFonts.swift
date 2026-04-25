//
//  MainFonts.swift
//  Ditto
//
//  Created by Codex on 4/25/26.
//

import SwiftUI

enum MainFont {
    enum PretendardWeight {
        case regular
        case medium
        case semibold
        case bold

        fileprivate var fontName: String {
            switch self {
            case .regular:
                return "Pretendard-Regular"
            case .medium:
                return "Pretendard-Medium"
            case .semibold:
                return "Pretendard-SemiBold"
            case .bold:
                return "Pretendard-Bold"
            }
        }
    }

    static func pretendard(_ weight: PretendardWeight, size: CGFloat) -> Font {
        .custom(weight.fontName, size: size)
    }

    static func paperlogyBlack(size: CGFloat) -> Font {
        .custom("Paperlogy-9Black", size: size)
    }
}
