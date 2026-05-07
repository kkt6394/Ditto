//
//  ActivityCardCanvasInkPalette.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import SwiftUI

// 그리기 모드일 때 캔버스 위에 떠 있는 잉크 팔레트.
// 8색 ScrollView + 굵기 stepper. ActivityCardCanvasView의 file_length를 줄이려고 분리.
struct ActivityCardCanvasInkPalette: View {
    @Bindable var viewModel: ActivityCardCanvasViewModel

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(0..<ActivityCardCanvasViewModel.inkPalette.count, id: \.self) { index in
                    inkColorCircle(index: index)
                }
                widthStepper
            }
            .padding(.horizontal, 16)
        }
    }

    private func inkColorCircle(index: Int) -> some View {
        let color = Color(uiColor: ActivityCardCanvasViewModel.inkPalette[index])
        let isSelected = viewModel.inkColorIndex == index
        return Circle()
            .fill(color)
            .frame(width: isSelected ? 32 : 26, height: isSelected ? 32 : 26)
            .overlay(
                Circle()
                    .stroke(
                        isSelected ? MainScreenPalette.primaryBlue : MainScreenPalette.border,
                        lineWidth: isSelected ? 3 : 1
                    )
            )
            .onTapGesture { viewModel.selectInkColor(index) }
    }

    private var widthStepper: some View {
        HStack(spacing: 6) {
            Image(systemName: "minus.circle")
                .onTapGesture { viewModel.inkWidth = max(1, viewModel.inkWidth - 1) }
            Text("\(Int(viewModel.inkWidth))pt")
                .font(MainScreenTypography.bodyCompact)
                .frame(width: 36)
            Image(systemName: "plus.circle")
                .onTapGesture { viewModel.inkWidth = min(20, viewModel.inkWidth + 1) }
        }
        .font(.system(size: 18, weight: .semibold))
        .foregroundStyle(MainScreenPalette.textPrimary)
    }
}
