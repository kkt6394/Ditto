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
        // 결제창 호출 시점을 startedAt으로 들고 있다가 백그라운드 복귀 시 응답 지연 여부 판단에 쓴다.
        case awaitingPayment(orderCode: String, amount: Int, startedAt: Date)
        // 결제창이 열린 채 일정 시간이 지나도 SDK 콜백이 오지 않은 상태. 사용자에게 결정권을 넘긴다.
        case awaitingPaymentStalled(orderCode: String, amount: Int, startedAt: Date)
        // PG 결제는 끝난 뒤 서버에 영수증 검증을 거는 단계. impUid를 보존해야 검증 단계 실패 시
        // 같은 결제로 재검증할 수 있어 이중결제를 막을 수 있다.
        case validating(orderCode: String, impUid: String)
        case completed(orderCode: String)
        case failed(message: String)
        // 결제는 정상 완료됐지만 검증 호출이 실패한 상태. impUid를 들고 있다가 재시도해야 한다.
        case validationFailed(orderCode: String, impUid: String, message: String)
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
    // 앱 강제종료/메모리 부족 등으로 검증 단계에서 죽었을 때 다음 부팅에서 복구할 수 있도록
    // 진행 중인 결제 정보를 디스크에 저장해두는 스토어다.
    private let pendingValidationStore: any PendingPaymentValidationStoring

    init(
        activity: ActivityResponseDTO,
        authManager: any AuthManaging,
        pendingValidationStore: any PendingPaymentValidationStoring = PendingPaymentValidationStore()
    ) {
        self.activity = activity
        self.authManager = authManager
        self.pendingValidationStore = pendingValidationStore
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
        case .idle, .completed, .failed, .validationFailed, .awaitingPaymentStalled:
            return false
        }
    }

    var pendingPayment: (orderCode: String, amount: Int)? {
        guard case let .awaitingPayment(orderCode, amount, _) = phase else {
            return nil
        }
        return (orderCode, amount)
    }

    // MARK: - Order + payment validation

    // ActivityDetailView가 시트를 닫을 때 호출. 결제 도중이면 흐름이 더럽혀지므로 idle만 닫게 한다.
    // validationFailed는 결제는 됐는데 검증만 실패한 상태라 사용자가 닫으면 영수증을 잃을 수 있어 막는다.
    // awaitingPaymentStalled는 사용자가 명시적으로 cancel 또는 retry를 선택하기 전엔 닫지 못하게 한다.
    var canDismiss: Bool {
        switch phase {
        case .idle, .completed, .failed:
            return true
        case .creatingOrder, .awaitingPayment, .validating, .validationFailed, .awaitingPaymentStalled:
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

            phase = .awaitingPayment(orderCode: response.orderCode, amount: amount, startedAt: Date())
        } catch {
            phase = .failed(message: Self.makeErrorMessage(from: error, fallback: "주문을 만들지 못했습니다."))
        }
    }

    func handlePaymentSuccess(impUid: String) async {
        // PG 결제창이 응답 늦어 stalled로 들어간 뒤에 SDK가 뒤늦게 콜백을 줄 수 있다. 이 경우에도 검증을
        // 진행해야 결제가 누락되지 않으므로 awaitingPayment / awaitingPaymentStalled 둘 다 받아준다.
        let orderCode: String
        switch phase {
        case .awaitingPayment(let code, _, _), .awaitingPaymentStalled(let code, _, _):
            orderCode = code
        default:
            return
        }

        await performValidation(orderCode: orderCode, impUid: impUid)
    }

    // ScenePhase가 active로 복귀했을 때 PaymentView가 호출. 결제창이 너무 오래 응답이 없으면
    // 사용자에게 결정권을 넘기기 위해 stalled 상태로 마킹한다. fullScreenCover는 launcherBinding이
    // nil이 되며 자동으로 닫혀 PaymentView 본체가 다시 보인다.
    func checkAwaitingPaymentStaleness(threshold: TimeInterval = 180) {
        guard case let .awaitingPayment(orderCode, amount, startedAt) = phase,
              Date().timeIntervalSince(startedAt) >= threshold else {
            return
        }

        phase = .awaitingPaymentStalled(orderCode: orderCode, amount: amount, startedAt: startedAt)
    }

    // 사용자가 stalled 화면에서 "결제 취소" 누를 때 호출. PG SDK는 백그라운드에 남아있을 수 있지만
    // 이후 콜백이 와도 phase가 .failed라 무시된다. 결제가 됐을 가능성은 OrderListView에서 사용자가 확인.
    func cancelStalledPayment() {
        guard case .awaitingPaymentStalled = phase else {
            return
        }

        phase = .failed(message: "결제 응답이 너무 오래 걸려 취소했습니다. 결제내역을 확인 후 다시 시도해 주세요.")
    }

    // 검증 단계에서 네트워크/서버 일시 오류가 났을 때 사용자가 누르는 진입점. 결제 자체는 끝났으니
    // 같은 impUid로 검증만 다시 시도한다 (PG 결제창은 다시 띄우지 않는다).
    func retryValidation() async {
        guard case let .validationFailed(orderCode, impUid, _) = phase else {
            return
        }

        await performValidation(orderCode: orderCode, impUid: impUid)
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

    // MARK: - Validation core

    // PG 결제 후 서버 검증을 수행. 일시적인 네트워크 단절이나 5xx는 자동으로 재시도해서
    // 결제는 됐는데 검증만 실패해 사용자가 다시 결제 시도하는(=이중결제) 시나리오를 줄인다.
    // 진입 시 디스크에 진행 정보를 저장해두면 앱이 죽어도 다음 부팅에서 복구할 수 있다.
    private func performValidation(orderCode: String, impUid: String) async {
        phase = .validating(orderCode: orderCode, impUid: impUid)
        pendingValidationStore.save(orderCode: orderCode, impUid: impUid)

        let backoffsInMilliseconds: [UInt64] = [500, 1_000, 2_000]
        var attemptIndex = 0
        let maxAttempts = backoffsInMilliseconds.count + 1

        while attemptIndex < maxAttempts {
            do {
                let networkManager = try makeNetworkManager()
                // 검증 응답은 결제 메타데이터가 가변적이라 디코딩 의존을 피하고 status code 성공만 확인한다.
                try await networkManager.send(
                    PaymentRouter.validate(PaymentValidationRequestDTO(impUid: impUid))
                )

                pendingValidationStore.clear()
                phase = .completed(orderCode: orderCode)
                return
            } catch {
                let isLastAttempt = attemptIndex == maxAttempts - 1
                if isLastAttempt || !Self.isRetriableValidationError(error) {
                    let message = Self.makeErrorMessage(from: error, fallback: "결제 검증에 실패했습니다.")
                    // store는 일부러 남겨둔다. 사용자가 retryValidation을 누르거나
                    // 다음 부팅 시 PaymentRecoveryService가 자동으로 다시 시도할 수 있게.
                    phase = .validationFailed(orderCode: orderCode, impUid: impUid, message: message)
                    return
                }

                let delay = backoffsInMilliseconds[attemptIndex]
                try? await Task.sleep(nanoseconds: delay * 1_000_000)
                attemptIndex += 1
            }
        }
    }

    // 네트워크 단절(URLSession 단계 실패)과 5xx는 같은 impUid로 다시 시도해도 멱등이라 재시도한다.
    // 4xx 같은 비즈니스 에러는 재시도해도 결과가 바뀌지 않으므로 즉시 실패 처리한다.
    private static func isRetriableValidationError(_ error: Error) -> Bool {
        guard let networkError = error as? NetworkError else {
            return false
        }

        switch networkError {
        case .requestFailed:
            return true
        case .statusCode(let code, _, _):
            return (500..<600).contains(code)
        case .invalidResponse:
            return true
        case .invalidURL, .missingAuthenticationToken, .encodingFailed, .decodingFailed:
            return false
        }
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
