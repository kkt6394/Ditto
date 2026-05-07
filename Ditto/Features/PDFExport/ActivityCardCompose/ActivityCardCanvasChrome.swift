//
//  ActivityCardCanvasChrome.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import SwiftUI

// 캔버스 화면 상단 툴바 칩 + 네비바. ActivityCardCanvasView의 file_length를 줄이려고 별도 파일로.
struct ToolbarChip: View {
    let systemImage: String
    let label: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ToolbarChipLabel(systemImage: systemImage, label: label, isActive: isActive)
        }
        .buttonStyle(.plain)
    }
}

struct ToolbarChipLabel: View {
    let systemImage: String
    let label: String
    let isActive: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
            Text(label)
                .font(MainFont.pretendard(.semibold, size: 13))
        }
        .foregroundStyle(isActive ? Color.white : MainScreenPalette.textPrimary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            isActive ? MainScreenPalette.primaryBlue : MainScreenPalette.surface,
            in: Capsule()
        )
        .overlay(Capsule().stroke(MainScreenPalette.border, lineWidth: 1))
    }
}

struct ActivityCardCanvasNavBar<Trailing: View>: View {
    let title: String
    let onClose: () -> Void
    let showsClose: Bool
    let trailing: () -> Trailing

    init(
        title: String,
        onClose: @escaping () -> Void,
        showsClose: Bool = true,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.onClose = onClose
        self.showsClose = showsClose
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            if showsClose {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(MainScreenPalette.textPrimary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 44, height: 44)
            }

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
