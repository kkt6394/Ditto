//
//  ReceiptView.swift
//  Ditto
//
//  Created by 김기태 on 5/5/26.
//

import SwiftUI

// orderCode로 GET /v1/payments/{orderCode}를 호출해 결제·주문 정보를 영수증 카드에 표시한다.
struct ReceiptView: View {
    private let orderCode: String

    @State private var viewModel: ReceiptViewModel

    init(orderCode: String, authManager: any AuthManaging) {
        self.orderCode = orderCode
        _viewModel = State(
            initialValue: ReceiptViewModel(orderCode: orderCode, authManager: authManager)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ReceiptNavigationBar(title: "영수증")

            content
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(MainScreenPalette.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.receipt == nil {
            SearchStateCard(
                title: "영수증을 불러오는 중입니다.",
                systemName: "arrow.clockwise"
            )
            .padding(.horizontal, 20)
        } else if let receipt = viewModel.receipt {
            ScrollView(showsIndicators: false) {
                ReceiptCard(receipt: receipt)
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 40)
            }
        } else {
            SearchStateCard(
                title: viewModel.message ?? "영수증을 표시할 수 없습니다.",
                subtitle: "주문번호 \(orderCode)",
                systemName: "exclamationmark.triangle"
            )
            .padding(.horizontal, 20)
        }
    }
}

private struct ReceiptNavigationBar: View {
    @Environment(\.dismiss) private var dismiss
    let title: String

    var body: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(title)
                .font(MainScreenTypography.brand)
                .foregroundStyle(MainScreenPalette.primaryBlue)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 4)
        .frame(height: 44)
    }
}

private struct ReceiptCard: View {
    let receipt: ReceiptOrderResponseDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReceiptRow(label: "결제 ID", value: receipt.paymentId)
            ReceiptRow(label: "주문 번호", value: receipt.orderItem.orderCode)
            ReceiptRow(
                label: "액티비티",
                value: receipt.orderItem.activity.title ?? "이름 없는 액티비티"
            )
            ReceiptRow(label: "품목", value: receipt.orderItem.reservationItemName)
            ReceiptRow(label: "일정", value: receipt.orderItem.reservationItemTime)
            ReceiptRow(label: "인원", value: "\(receipt.orderItem.participantCount)명")
            ReceiptRow(label: "결제 일자", value: receipt.orderItem.paidAt)

            Divider()
                .overlay(MainScreenPalette.border)

            HStack {
                Text("총 결제 금액")
                    .font(MainFont.pretendard(.semibold, size: 14))
                    .foregroundStyle(MainScreenPalette.textSecondary)

                Spacer()

                Text(ActivityFormatting.makePriceText(Double(receipt.orderItem.totalPrice)))
                    .font(MainFont.pretendard(.bold, size: 18))
                    .foregroundStyle(MainScreenPalette.textPrimary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MainScreenPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MainScreenPalette.border, lineWidth: 1)
        )
    }
}

private struct ReceiptRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(MainFont.pretendard(.semibold, size: 13))
                .foregroundStyle(MainScreenPalette.textSecondary)
                .frame(width: 76, alignment: .leading)

            Text(value)
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
        }
    }
}
