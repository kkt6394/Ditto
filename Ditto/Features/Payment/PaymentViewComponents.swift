//
//  PaymentViewComponents.swift
//  Ditto
//
//  Created by Codex on 4/30/26.
//

import SwiftUI

// PaymentView 본체를 슬림하게 유지하기 위해 패널 단위 컴포넌트를 분리한다.
// 각 패널은 PaymentViewModel의 일부를 직접 참조하거나 필요한 값만 받아 단순 표시 책임만 진다.

struct PaymentNavigationBar: View {
    let canDismiss: Bool
    let onClose: () -> Void

    var body: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .disabled(!canDismiss)

            Spacer()

            Text("결제")
                .font(MainScreenTypography.brand)
                .foregroundStyle(MainScreenPalette.primaryBlue)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 4)
        .frame(height: 44)
        .background(MainScreenPalette.background)
    }
}

struct PaymentActivitySummaryPanel: View {
    let activity: ActivityResponseDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(activity.title ?? "제목 없는 액티비티")
                .font(MainFont.paperlogyBlack(size: 22))
                .foregroundStyle(MainScreenPalette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text("판매가 \(formattedPaymentPrice(activity.price.final)) / 인")
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(MainScreenPalette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MainScreenPalette.border, lineWidth: 1)
        )
    }
}

struct PaymentReservationSelectionPanel: View {
    let viewModel: PaymentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("예약 정보")
                .font(MainScreenTypography.sectionTitle)
                .foregroundStyle(MainScreenPalette.textPrimary)

            if viewModel.availableItemNames.isEmpty {
                Text("예약 가능한 항목이 없습니다.")
                    .font(MainScreenTypography.body)
                    .foregroundStyle(MainScreenPalette.textSecondary)
            } else {
                reservationItemMenu
                reservationTimeMenu
            }
        }
    }

    private var reservationItemMenu: some View {
        Menu {
            ForEach(viewModel.availableItemNames, id: \.self) { itemName in
                Button(itemName) {
                    viewModel.selectItem(itemName)
                }
            }
        } label: {
            menuLabel(text: viewModel.selectedItemName ?? "예약 항목 선택")
        }
        .disabled(viewModel.isProcessing)
    }

    @ViewBuilder
    private var reservationTimeMenu: some View {
        if viewModel.availableTimes.isEmpty {
            Text("선택한 항목에 예약 가능한 시간이 없습니다.")
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textSecondary)
        } else {
            Menu {
                ForEach(viewModel.availableTimes, id: \.self) { time in
                    Button(time) {
                        viewModel.selectTime(time)
                    }
                }
            } label: {
                menuLabel(text: viewModel.selectedTime ?? "시간 선택")
            }
            .disabled(viewModel.isProcessing)
        }
    }

    private func menuLabel(text: String) -> some View {
        HStack {
            Text(text)
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textPrimary)
            Spacer()
            Image(systemName: "chevron.down")
                .foregroundStyle(MainScreenPalette.textSecondary)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(MainScreenPalette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(MainScreenPalette.border, lineWidth: 1)
        )
    }
}

struct PaymentParticipantStepperPanel: View {
    @Bindable var viewModel: PaymentViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("참여 인원")
                .font(MainScreenTypography.sectionTitle)
                .foregroundStyle(MainScreenPalette.textPrimary)

            HStack {
                Text("\(viewModel.participantCount)명")
                    .font(MainFont.pretendard(.bold, size: 18))
                    .foregroundStyle(MainScreenPalette.textPrimary)
                Spacer()
                Stepper(
                    value: $viewModel.participantCount,
                    in: 1...viewModel.maxParticipantCount
                ) {
                    EmptyView()
                }
                .labelsHidden()
                .disabled(viewModel.isProcessing)
            }
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(MainScreenPalette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(MainScreenPalette.border, lineWidth: 1)
            )

            Text("최대 \(viewModel.maxParticipantCount)명까지 가능합니다.")
                .font(MainScreenTypography.timestamp)
                .foregroundStyle(MainScreenPalette.textMuted)
        }
    }
}

struct PaymentPriceSummaryPanel: View {
    let totalAmount: Int

    var body: some View {
        HStack {
            Text("총 결제 금액")
                .font(MainScreenTypography.sectionTitle)
                .foregroundStyle(MainScreenPalette.textPrimary)
            Spacer()
            Text(formattedPaymentPrice(Double(totalAmount)))
                .font(MainFont.paperlogyBlack(size: 22))
                .foregroundStyle(MainScreenPalette.primaryBlue)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(16)
        .background(MainScreenPalette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MainScreenPalette.border, lineWidth: 1)
        )
    }
}

struct PaymentPayButton: View {
    let title: String
    let isProcessing: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isProcessing {
                    ProgressView()
                        .tint(.white)
                }
                Text(title)
                    .font(MainFont.pretendard(.bold, size: 16))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                isEnabled ? MainScreenPalette.primaryBlue : MainScreenPalette.textMuted,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}
