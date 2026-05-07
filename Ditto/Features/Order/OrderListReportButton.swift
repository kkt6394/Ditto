//
//  OrderListReportButton.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import SwiftUI

// 주문 내역 화면 우상단의 "활동 리포트 PDF" 진입 버튼.
// 별도 파일로 분리해 OrderListView의 type/file 길이가 부풀어 SwiftLint 한계에 닿지 않게 한다.
struct OrderListReportButton: View {
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "square.and.arrow.up.on.square")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(
                    isDisabled
                        ? MainScreenPalette.textMuted
                        : MainScreenPalette.textPrimary
                )
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}
