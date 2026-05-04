//
//  PaymentViewModel.swift
//  Ditto
//
//  Created by Codex on 4/30/26.
//

import Foundation
import Observation

// 결제 흐름 단계: 주문 생성 → 결제창 호출 대기 → 검증 → 완료/실패.
// 각 화면 분기와 버튼 비활성화 조건을 enum 한 곳에서 결정한다.
@MainActor
@Observable
final class PaymentViewModel {
    enum Phase: Equatable {
        case idle
        case creatingOrder
        case awaitingPayment(orderCode: String, amount: Int)
        case validating(orderCode: String)
        case completed(orderCode: String)
        case failed(message: String)
    }

    let activity: ActivityResponseDTO

    private(set) var phase: Phase = .idle

    private(set) var availableItemNames: [String]
    private(set) var availableTimes: [String]
    private(set) var selectedItemName: String?
    private(set) var selectedTime: String?

    var participantCount: Int = 1
    private(set) var maxParticipantCount: Int

    private let authManager: any AuthManaging

    init(activity: ActivityResponseDTO, authManager: any AuthManaging) {
        self.activity = activity
        self.authManager = authManager
        self.availableItemNames = activity.reservationList.map { $0.itemName }
        self.maxParticipantCount = max(Int(activity.restrictions.maxParticipants), 1)

        // 첫 예약 항목과 예약 가능한 첫 시간을 기본값으로 채운다.
        let firstItem = activity.reservationList.first
        self.selectedItemName = firstItem?.itemName
        self.availableTimes = Self.makeAvailableTimes(from: firstItem)
        self.selectedTime = self.availableTimes.first
    }

    // MARK: - Selection

    func selectItem(_ itemName: String) {
        guard availableItemNames.contains(itemName) else {
            return
        }

        selectedItemName = itemName
        let item = activity.reservationList.first { $0.itemName == itemName }
        availableTimes = Self.makeAvailableTimes(from: item)
        // 새 항목으로 바꾸면 이전 시간 선택은 더 이상 유효하지 않을 수 있어 첫 시간으로 초기화한다.
        selectedTime = availableTimes.first
    }

    func selectTime(_ time: String) {
        guard availableTimes.contains(time) else {
            return
        }

        selectedTime = time
    }

    // MARK: - Derived state

    var isReservable: Bool {
        selectedItemName != nil && selectedTime != nil
    }

    var totalAmount: Int {
        let unitPrice = Int(activity.price.final.rounded())
        return unitPrice * max(participantCount, 1)
    }

    var isProcessing: Bool {
        switch phase {
        case .creatingOrder, .awaitingPayment, .validating:
            return true
        case .idle, .completed, .failed:
            return false
        }
    }

    var pendingPayment: (orderCode: String, amount: Int)? {
        guard case let .awaitingPayment(orderCode, amount) = phase else {
            return nil
        }
        return (orderCode, amount)
    }

    // MARK: - Order + payment validation

    // ActivityDetailView가 시트를 닫을 때 호출. 결제 도중이면 흐름이 더럽혀지므로 idle만 닫게 한다.
    var canDismiss: Bool {
        switch phase {
        case .idle, .completed, .failed:
            return true
        case .creatingOrder, .awaitingPayment, .validating:
            return false
        }
    }

    func startOrder() async {
        guard !isProcessing else {
            return
        }

        guard let itemName = selectedItemName, let time = selectedTime else {
            phase = .failed(message: "예약 항목과 시간을 선택해 주세요.")
            return
        }

        phase = .creatingOrder

        do {
            let networkManager = try makeNetworkManager()
            let amount = totalAmount
            let request = OrderCreateRequestDTO(
                activityId: activity.activityId,
                reservationItemName: itemName,
                reservationItemTime: time,
                participantCount: participantCount,
                totalPrice: amount
            )

            let response: OrderCreateResponseDTO = try await networkManager.request(
                OrderRouter.create(request)
            )

            phase = .awaitingPayment(orderCode: response.orderCode, amount: amount)
        } catch {
            phase = .failed(message: Self.makeErrorMessage(from: error, fallback: "주문을 만들지 못했습니다."))
        }
    }

    func handlePaymentSuccess(impUid: String) async {
        guard case let .awaitingPayment(orderCode, _) = phase else {
            return
        }

        phase = .validating(orderCode: orderCode)

        do {
            let networkManager = try makeNetworkManager()
            // 검증 응답은 결제 메타데이터가 가변적이라 디코딩 의존을 피하고 status code 성공만 확인한다.
            try await networkManager.send(
                PaymentRouter.validate(PaymentValidationRequestDTO(impUid: impUid))
            )

            phase = .completed(orderCode: orderCode)
        } catch {
            phase = .failed(message: Self.makeErrorMessage(from: error, fallback: "결제 검증에 실패했습니다."))
        }
    }

    func handlePaymentFailure(message: String?) {
        let safeMessage = (message?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { value in
            value.isEmpty ? nil : value
        }
        phase = .failed(message: safeMessage ?? "결제가 취소되었거나 진행되지 않았습니다.")
    }

    func resetAfterFailure() {
        phase = .idle
    }

    // MARK: - Helpers

    private func makeNetworkManager() throws -> any NetworkManaging {
        let configuration = try AppConfiguration()
        return NetworkManager(configuration: configuration, authManager: authManager)
    }

    private static func makeAvailableTimes(from item: ActivityReservationItemDTO?) -> [String] {
        guard let item else {
            return []
        }

        return item.times.compactMap { slot in
            guard let time = slot.time, !(slot.isReserved ?? false) else {
                return nil
            }
            return time
        }
    }

    private static func makeErrorMessage(from error: Error, fallback: String) -> String {
        NetworkErrorMapper.userMessage(from: error, fallback: fallback)
    }
}
