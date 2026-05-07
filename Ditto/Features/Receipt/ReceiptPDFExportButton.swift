//
//  ReceiptPDFExportButton.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import SwiftUI

// 영수증 화면 우상단의 "PDF" 진입 버튼.
// 별도 파일로 빼서 ReceiptView의 file_length가 SwiftLint 한계에 닿지 않게 한다.
struct ReceiptPDFExportButton: View {
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "square.and.arrow.up")
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
