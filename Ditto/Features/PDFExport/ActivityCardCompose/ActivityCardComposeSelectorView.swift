//
//  ActivityCardComposeSelectorView.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import SwiftUI

// 액티비티 카드 만들기 — 활동 선택 화면.
// 사용자가 주문 1개~여러 개를 골라 캔버스로 진입한다.
struct ActivityCardComposeSelectorView: View {
    private let authManager: any AuthManaging

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ActivityCardComposeSelectorViewModel
    @State private var isPresentingCanvas = false

    init(authManager: any AuthManaging) {
        self.authManager = authManager
        _viewModel = State(
            initialValue: ActivityCardComposeSelectorViewModel(authManager: authManager)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ActivityCardComposeNavBar(title: "액티비티 카드 만들기")

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(MainScreenPalette.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        .fullScreenCover(isPresented: $isPresentingCanvas) {
            ActivityCardCanvasView(
                orders: viewModel.selectedOrders,
                authManager: authManager
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.orders.isEmpty {
            SearchStateCard(
                title: "주문 내역을 불러오는 중입니다.",
                systemName: "arrow.clockwise"
            )
            .padding(.horizontal, 20)
        } else if viewModel.orders.isEmpty {
            SearchStateCard(
                title: viewModel.message ?? "참여한 액티비티가 없어요.",
                subtitle: "결제한 액티비티가 있어야 카드를 만들 수 있어요.",
                systemName: "doc.text.magnifyingglass"
            )
            .padding(.horizontal, 20)
        } else {
            VStack(spacing: 0) {
                Text("카드에 넣을 액티비티를 골라보세요.")
                    .font(MainScreenTypography.body)
                    .foregroundStyle(MainScreenPalette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                selectorList

                nextButton
            }
        }
    }

    private var selectorList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(
                    Array(viewModel.orders.enumerated()),
                    id: \.element.orderId
                ) { index, order in
                    ActivityCardComposeRow(
                        order: order,
                        isSelected: viewModel.selectedOrderIds.contains(order.orderId)
                    ) {
                        viewModel.toggle(order)
                    }

                    if index != viewModel.orders.indices.last {
                        Divider()
                            .padding(.horizontal, 20)
                            .overlay(MainScreenPalette.border)
                    }
                }
            }
            .padding(.bottom, 100)
        }
    }

    private var nextButton: some View {
        Button {
            isPresentingCanvas = true
        } label: {
            Text("다음 (\(viewModel.selectedOrderIds.count)개 선택)")
                .font(MainFont.pretendard(.bold, size: 16))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    viewModel.hasSelection
                        ? MainScreenPalette.primaryBlue
                        : MainScreenPalette.textMuted,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(!viewModel.hasSelection)
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }
}

private struct ActivityCardComposeNavBar: View {
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

            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 4)
        .frame(height: 44)
    }
}

private struct ActivityCardComposeRow: View {
    let order: OrderReviewResponseDTO
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(
                        isSelected
                            ? MainScreenPalette.primaryBlue
                            : MainScreenPalette.textMuted
                    )
                    .frame(width: 28, height: 28)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text(order.activity.title ?? "이름 없는 액티비티")
                        .font(MainFont.pretendard(.bold, size: 15))
                        .foregroundStyle(MainScreenPalette.textPrimary)
                        .lineLimit(2)
                    Text(order.reservationItemName)
                        .font(MainScreenTypography.body)
                        .foregroundStyle(MainScreenPalette.textSecondary)
                        .lineLimit(1)
                    Text("일정 \(order.reservationItemTime) · \(order.participantCount)명")
                        .font(MainScreenTypography.bodyCompact)
                        .foregroundStyle(MainScreenPalette.textMuted)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(MainScreenPalette.surface)
        }
        .buttonStyle(.plain)
    }
}
