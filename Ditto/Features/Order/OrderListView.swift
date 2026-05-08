//
//  OrderListView.swift
//  Ditto
//
//  Created by 김기태 on 5/5/26.
//

import SwiftUI

// /v1/orders 응답을 LazyVStack에 표시한다. 단발 호출이라 페이지네이션은 없다.
struct OrderListView: View {
    private let authManager: any AuthManaging
    // (orderCode, activityId, existingReviewId?, thumbnailPath?) — 영수증 + 리뷰 + PDF 추출에 필요한 정보
    private let receiptAction: (String, String, String?, String?) -> Void

    @State private var viewModel: OrderListViewModel

    init(
        authManager: any AuthManaging,
        receiptAction: @escaping (String, String, String?, String?) -> Void
    ) {
        self.authManager = authManager
        self.receiptAction = receiptAction
        _viewModel = State(initialValue: OrderListViewModel(authManager: authManager))
    }

    var body: some View {
        VStack(spacing: 0) {
            OrderListNavigationBar(title: "주문 내역")

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
        if viewModel.isLoading && viewModel.orders.isEmpty {
            SearchStateCard(
                title: "주문 내역을 불러오는 중입니다.",
                systemName: "arrow.clockwise"
            )
            .padding(.horizontal, 20)
        } else if viewModel.orders.isEmpty {
            SearchStateCard(
                title: viewModel.message ?? "주문 내역이 없습니다.",
                subtitle: "결제한 액티비티가 없으면 비어 있습니다.",
                systemName: "doc.text.magnifyingglass"
            )
            .padding(.horizontal, 20)
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(
                        Array(viewModel.orders.enumerated()),
                        id: \.element.orderId
                    ) { index, order in
                        OrderRowCard(order: order, imageRequest: imageRequest(for: order))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                receiptAction(
                                    order.orderCode,
                                    order.activity.id,
                                    order.review?.id,
                                    order.activity.thumbnails.first
                                )
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
    }

    // 액티비티 썸네일을 ChatBubble/SearchRemoteImage와 동일한 인증 흐름(SeSACKey + Authorization)으로 요청한다.
    private func imageRequest(for order: OrderReviewResponseDTO) -> URLRequest? {
        guard let path = order.activity.thumbnails.first,
              let configuration = try? AppConfiguration() else {
            return nil
        }
        return ActivityFormatting.makeImageRequest(
            from: path,
            configuration: configuration,
            accessToken: authManager.tokens?.accessToken
        )
    }
}

private struct OrderListNavigationBar<Trailing: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let trailing: () -> Trailing

    init(title: String, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        // 타이틀은 ZStack 중앙에 고정한다. trailing이 EmptyView일 때 minWidth 프레임이 SwiftUI에서
        // 실제 폭을 안 잡아 좌측 chevron(44pt)과 비대칭으로 어긋나던 문제를 끊는 패턴.
        ZStack {
            Text(title)
                .font(MainScreenTypography.brand)
                .foregroundStyle(MainScreenPalette.primaryBlue)

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

                trailing()
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 44)
    }
}

private struct OrderRowCard: View {
    let order: OrderReviewResponseDTO
    // 인증 헤더 박힌 액티비티 썸네일 요청. nil이면 SearchRemoteImage가 fallback 이미지를 그린다.
    let imageRequest: URLRequest?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SearchRemoteImage(
                request: imageRequest,
                fallbackImageName: "FigmaMainNewActivity1",
                width: 84,
                height: 84,
                cornerRadius: 12
            )
            // URL 변경 시 캐시된 UIImage가 그대로 보이는 걸 막기 위해 URL 기반 id로 강제 재생성.
            .id(imageRequest?.url?.absoluteString ?? "")

            VStack(alignment: .leading, spacing: 6) {
                Text(order.activity.title ?? "이름 없는 액티비티")
                    .font(MainFont.pretendard(.bold, size: 15))
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .lineLimit(2)

                Text(order.reservationItemName)
                    .font(MainScreenTypography.body)
                    .foregroundStyle(MainScreenPalette.textSecondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("일정 \(order.reservationItemTime)")
                        .font(MainScreenTypography.bodyCompact)
                        .foregroundStyle(MainScreenPalette.textMuted)

                    Text("· \(order.participantCount)명")
                        .font(MainScreenTypography.bodyCompact)
                        .foregroundStyle(MainScreenPalette.textMuted)
                }

                HStack {
                    Text(ActivityFormatting.makePriceText(Double(order.totalPrice)))
                        .font(MainFont.pretendard(.bold, size: 15))
                        .foregroundStyle(MainScreenPalette.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(MainScreenPalette.textMuted)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(MainScreenPalette.surface)
    }
}
