//
//  PaymentView.swift
//  Ditto
//
//  Created by Codex on 4/30/26.
//

import iamport_ios
import SwiftUI

struct PaymentView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: PaymentViewModel
    @State private var configurationError: String?
    @State private var configuration: AppConfiguration?

    private let onCompleted: (String) -> Void

    init(
        activity: ActivityResponseDTO,
        authManager: any AuthManaging,
        onCompleted: @escaping (String) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: PaymentViewModel(activity: activity, authManager: authManager))
        self.onCompleted = onCompleted
    }

    var body: some View {
        VStack(spacing: 0) {
            PaymentNavigationBar(canDismiss: viewModel.canDismiss) {
                dismiss()
            }

            content
        }
        .background(MainScreenPalette.background.ignoresSafeArea())
        .task { loadConfiguration() }
        .fullScreenCover(item: launcherBinding) { context in
            PaymentLauncher(
                userCode: context.userCode,
                payment: context.payment
            ) { response in
                Task { @MainActor in
                    await handlePaymentResult(response)
                }
            }
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .completed(let orderCode):
            PaymentResultView(
                style: .success,
                title: "결제가 완료되었어요",
                message: "주문번호 \(orderCode)",
                primaryActionTitle: "확인"
            ) {
                onCompleted(orderCode)
                dismiss()
            }
        case .failed(let message):
            // 마지막 인자가 클로저라 trailing_closure 룰을 발동시키지만, 클로저가 둘이라 trailing을 쓰면
            // multiple_closures_with_trailing_closure 룰을 위반한다. 두 룰 충돌이라 호출 블록만 비활성화.
            // swiftlint:disable trailing_closure
            PaymentResultView(
                style: .failure,
                title: "결제를 완료하지 못했어요",
                message: message,
                primaryActionTitle: "다시 시도",
                primaryAction: { viewModel.resetAfterFailure() },
                secondaryActionTitle: "닫기",
                secondaryAction: { dismiss() }
            )
            // swiftlint:enable trailing_closure
        default:
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    PaymentActivitySummaryPanel(activity: viewModel.activity)
                    PaymentReservationSelectionPanel(viewModel: viewModel)
                    PaymentParticipantStepperPanel(viewModel: viewModel)
                    PaymentPriceSummaryPanel(totalAmount: viewModel.totalAmount)
                    PaymentPayButton(
                        title: payButtonTitle,
                        isProcessing: viewModel.isProcessing,
                        isEnabled: isPayButtonEnabled
                    ) {
                        Task { @MainActor in
                            await viewModel.startOrder()
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Pay button derived state

    private var payButtonTitle: String {
        switch viewModel.phase {
        case .creatingOrder:
            return "주문을 만드는 중…"
        case .awaitingPayment, .validating:
            return "결제 진행 중…"
        default:
            return "\(formattedPaymentPrice(Double(viewModel.totalAmount))) 결제하기"
        }
    }

    private var isPayButtonEnabled: Bool {
        viewModel.isReservable && !viewModel.isProcessing && configurationError == nil
    }

    // MARK: - Launcher

    private var launcherBinding: Binding<PaymentLauncherContext?> {
        Binding(
            get: { makeLauncherContext() },
            set: { newValue in
                // SwiftUI가 fullScreenCover를 닫을 때 nil로 set한다. 이 경로는 SDK가 결제 결과를
                // onComplete로 직접 알리므로 별도 처리할 필요가 없다.
                _ = newValue
            }
        )
    }

    private func makeLauncherContext() -> PaymentLauncherContext? {
        guard let pending = viewModel.pendingPayment,
              let configuration,
              let userCode = configuration.impUserCode else {
            return nil
        }

        let pgString = configuration.impPG ?? PG.html5_inicis.rawValue
        let payment = IamportPayment(
            pg: pgString,
            merchant_uid: pending.orderCode,
            amount: "\(pending.amount)"
        )
        payment.pay_method = PayMethod.card.rawValue
        payment.name = viewModel.activity.title
        payment.app_scheme = "ditto"

        return PaymentLauncherContext(
            id: pending.orderCode,
            userCode: userCode,
            payment: payment
        )
    }

    private func handlePaymentResult(_ response: IamportResponse?) async {
        guard let response else {
            viewModel.handlePaymentFailure(message: nil)
            return
        }

        if response.success == true, let impUid = response.imp_uid {
            await viewModel.handlePaymentSuccess(impUid: impUid)
        } else {
            viewModel.handlePaymentFailure(message: response.error_msg)
        }
    }

    private func loadConfiguration() {
        do {
            let loaded = try AppConfiguration()
            configuration = loaded

            if loaded.impUserCode == nil {
                configurationError = "결제 식별코드(IMP_USER_CODE)가 설정되지 않았습니다."
                viewModel.handlePaymentFailure(message: configurationError)
            }
        } catch {
            configurationError = "결제 설정을 불러오지 못했습니다."
            viewModel.handlePaymentFailure(message: configurationError)
        }
    }
}

// 가격 표기는 컴포넌트 여러 곳에서 재사용되므로 file scope helper로 둔다.
func formattedPaymentPrice(_ price: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    let value = formatter.string(from: NSNumber(value: price)) ?? "\(Int(price))"
    return "\(value)원"
}

// fullScreenCover(item:)에 전달할 컨텍스트. orderCode를 ID로 사용해 중복 호출을 막는다.
struct PaymentLauncherContext: Identifiable, Equatable {
    let id: String
    let userCode: String
    let payment: IamportPayment

    static func == (lhs: PaymentLauncherContext, rhs: PaymentLauncherContext) -> Bool {
        lhs.id == rhs.id && lhs.userCode == rhs.userCode
    }
}
