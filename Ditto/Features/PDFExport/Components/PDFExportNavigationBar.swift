//
//  PDFExportNavigationBar.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import SwiftUI

// PDF Export 화면들이 공유하는 커스텀 네비바.
// 좌측 닫기 / 가운데 타이틀 / 우측 슬롯 (재설정·공유 등) 구조.
struct PDFExportNavigationBar<Trailing: View>: View {
    let title: String
    let onClose: () -> Void
    let trailing: () -> Trailing

    init(
        title: String,
        onClose: @escaping () -> Void,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.onClose = onClose
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(title)
                .font(MainScreenTypography.brand)
                .foregroundStyle(MainScreenPalette.primaryBlue)

            Spacer()

            trailing()
        }
        .padding(.horizontal, 4)
        .frame(height: 44)
    }
}
