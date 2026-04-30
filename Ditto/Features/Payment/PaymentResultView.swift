//
//  PaymentResultView.swift
//  Ditto
//
//  Created by Codex on 4/30/26.
//

import SwiftUI

// 결제 완료/실패 공통 화면. 외부에서 텍스트와 액션만 주입해서 동일한 레이아웃을 재사용한다.
struct PaymentResultView: View {
    enum Style {
        case success
        case failure
    }

    let style: Style
    let title: String
    let message: String
    let primaryActionTitle: String
    let primaryAction: () -> Void
    var secondaryActionTitle: String?
    var secondaryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .foregroundStyle(iconColor)

            Text(title)
                .font(MainFont.paperlogyBlack(size: 22))
                .foregroundStyle(MainScreenPalette.textPrimary)
                .multilineTextAlignment(.center)

            Text(message)
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            VStack(spacing: 10) {
                Button(action: primaryAction) {
                    Text(primaryActionTitle)
                        .font(MainFont.pretendard(.bold, size: 16))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            MainScreenPalette.primaryBlue,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                }
                .buttonStyle(.plain)

                if let secondaryActionTitle, let secondaryAction {
                    Button(action: secondaryAction) {
                        Text(secondaryActionTitle)
                            .font(MainFont.pretendard(.bold, size: 16))
                            .foregroundStyle(MainScreenPalette.primaryBlue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MainScreenPalette.background.ignoresSafeArea())
    }

    private var iconName: String {
        switch style {
        case .success:
            return "checkmark.circle.fill"
        case .failure:
            return "xmark.octagon.fill"
        }
    }

    private var iconColor: Color {
        switch style {
        case .success:
            return MainScreenPalette.primaryBlue
        case .failure:
            return .red
        }
    }
}
