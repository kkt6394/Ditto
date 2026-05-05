//
//  ReceiptViewModel.swift
//  Ditto
//
//  Created by Codex on 5/4/26.
//

import Foundation
import Observation

// 영수증 조회 ViewModel.
// orderCode로 GET /v1/payments/{orderCode} 호출 → 포트원 결제 영수증 정보 조회.
@MainActor
@Observable
final class ReceiptViewModel {
    let orderCode: String

    private(set) var receipt: PaymentResponseDTO?
    private(set) var isLoading = false
    var message: String?

    private let networkManagerProvider: @MainActor () throws -> any NetworkManaging

    convenience init(orderCode: String, authManager: any AuthManaging) {
        self.init(orderCode: orderCode) {
            let configuration = try AppConfiguration()
            return NetworkManager(configuration: configuration, authManager: authManager)
        }
    }

    init(
        orderCode: String,
        networkManagerProvider: @escaping @MainActor () throws -> any NetworkManaging
    ) {
        self.orderCode = orderCode
        self.networkManagerProvider = networkManagerProvider
    }

    func load() async {
        isLoading = true
        message = nil
        defer { isLoading = false }

        do {
            let networkManager = try networkManagerProvider()
            let response: PaymentResponseDTO = try await networkManager.request(
                PaymentRouter.receipt(orderCode: orderCode)
            )
            receipt = response
        } catch {
            message = NetworkErrorMapper.userMessage(from: error, fallback: "영수증을 불러오지 못했습니다.")
        }
    }
}
