//
//  ReceiptView.swift
//  Ditto
//
//  Created by 김기태 on 5/5/26.
//

import SwiftUI
import UIKit

// orderCode로 GET /v1/payments/{orderCode}를 호출해 결제·주문 정보를 영수증 카드에 표시한다.
struct ReceiptView: View {
    private let orderCode: String
    private let activityId: String
    // 이미 작성된 리뷰가 있으면 reviewId — 화면에 "리뷰 작성됨" 안내를 표시하고 작성 진입을 막는다.
    private let existingReviewId: String?
    // OrderListView에서 같이 넘어온 액티비티 첫 번째 썸네일 path. PDF 출력 시 이미지로 사용.
    private let thumbnailPath: String?
    private let authManager: any AuthManaging

    @State private var viewModel: ReceiptViewModel
    @State private var isPresentingReviewCompose = false
    // 화면 진입 시점엔 existingReviewId가 nil이어도, 시트에서 작성 완료 시 즉시 UI를 갱신하기 위한 플래그
    @State private var hasJustReviewed = false

    init(
        orderCode: String,
        activityId: String,
        existingReviewId: String?,
        thumbnailPath: String?,
        authManager: any AuthManaging
    ) {
        self.orderCode = orderCode
        self.activityId = activityId
        self.existingReviewId = existingReviewId
        self.thumbnailPath = thumbnailPath
        self.authManager = authManager
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
        // 시스템 네비바를 숨기면 좌측 엣지 스와이프-백도 같이 막혀, gesture를 다시 살려준다.
        .background(InteractivePopGestureEnabler())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.load()
        }
        .sheet(isPresented: $isPresentingReviewCompose) {
            ReviewComposeView(
                activityId: activityId,
                mode: .create(orderCode: orderCode),
                authManager: authManager
            ) {
                // 작성 성공 시 즉시 UI에 반영. OrderList로 돌아가면 서버 상태로 다시 동기화된다.
                hasJustReviewed = true
            }
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
                VStack(spacing: 16) {
                    ReceiptCard(receipt: receipt)

                    reviewActionButton
                }
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

    @ViewBuilder
    private var reviewActionButton: some View {
        if existingReviewId == nil && !hasJustReviewed {
            Button {
                isPresentingReviewCompose = true
            } label: {
                Text("리뷰 쓰기")
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
        } else {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(MainScreenPalette.primaryBlue)

                Text("이미 리뷰를 작성한 주문입니다. 수정·삭제는 액티비티 상세에서 가능합니다.")
                    .font(MainScreenTypography.body)
                    .foregroundStyle(MainScreenPalette.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                MainScreenPalette.primaryBlueSoft,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
    }
}

private struct ReceiptNavigationBar<Trailing: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let trailing: () -> Trailing

    init(title: String, @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing
    }

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

            trailing()
                .frame(minWidth: 44, minHeight: 44)
        }
        .padding(.horizontal, 4)
        .frame(height: 44)
    }
}

private struct ReceiptCard: View {
    let receipt: PaymentResponseDTO

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ReceiptRow(label: "결제 ID", value: receipt.impUid)
            ReceiptRow(label: "주문 번호", value: receipt.merchantUid)
            ReceiptRow(label: "액티비티", value: receipt.name ?? "이름 없는 액티비티")
            ReceiptRow(label: "결제 수단", value: receipt.payMethod ?? "-")

            if let cardDisplay = makeCardDisplay() {
                ReceiptRow(label: "카드", value: cardDisplay)
            }

            ReceiptRow(label: "PG", value: receipt.pgProvider ?? "-")
            ReceiptRow(label: "결제 상태", value: receipt.status)
            ReceiptRow(label: "결제 일자", value: receipt.paidAt)

            Divider()
                .overlay(MainScreenPalette.border)

            HStack {
                Text("총 결제 금액")
                    .font(MainFont.pretendard(.semibold, size: 14))
                    .foregroundStyle(MainScreenPalette.textSecondary)

                Spacer()

                Text(ActivityFormatting.makePriceText(Double(receipt.amount)))
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

    private func makeCardDisplay() -> String? {
        // 카드명/번호 둘 다 없으면 행 자체를 숨겨 빈 값을 보여주지 않는다.
        switch (receipt.cardName, receipt.cardNumber) {
        case (let name?, let number?):
            return "\(name) \(number)"
        case (let name?, nil):
            return name
        case (nil, let number?):
            return number
        default:
            return nil
        }
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

// MARK: - 인터랙티브 팝 제스처 복구

// 커스텀 네비바를 쓰며 시스템 네비바를 숨길 때 좌측 엣지 스와이프-백이 사라지는 SwiftUI 한계를 우회한다.
// 화면이 attach되면 부모 UINavigationController를 찾아 interactivePopGestureRecognizer의 delegate를 nil로 풀어
// 시스템이 back button 존재 여부와 무관하게 제스처를 처리하게 만든다.
private struct InteractivePopGestureEnabler: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        // 뷰 계층에 붙은 직후엔 nav controller가 아직 nil일 수 있어 다음 runloop에서 시도한다.
        DispatchQueue.main.async {
            guard let navController = view.nearestNavigationController else { return }
            navController.interactivePopGestureRecognizer?.delegate = nil
            navController.interactivePopGestureRecognizer?.isEnabled = true
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

private extension UIView {
    var nearestNavigationController: UINavigationController? {
        var responder: UIResponder? = self
        while let next = responder?.next {
            if let navController = next as? UINavigationController {
                return navController
            }
            if let viewController = next as? UIViewController,
               let navController = viewController.navigationController {
                return navController
            }
            responder = next
        }
        return nil
    }
}
