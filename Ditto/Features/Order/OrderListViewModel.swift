//
//  OrderListViewModel.swift
//  Ditto
//
//  Created by Codex on 5/4/26.
//

import Foundation
import Observation

// 내 주문 내역 조회 ViewModel.
// /v1/orders 응답에는 페이지네이션이 없어 단발 호출만 한다.
@MainActor
@Observable
final class OrderListViewModel {
    private(set) var orders: [OrderReviewResponseDTO] = []
    private(set) var isLoading = false
    var message: String?

    private let networkManagerProvider: @MainActor () throws -> any NetworkManaging

    convenience init(authManager: any AuthManaging) {
        self.init {
            let configuration = try AppConfiguration()
            return NetworkManager(configuration: configuration, authManager: authManager)
        }
    }

    init(networkManagerProvider: @escaping @MainActor () throws -> any NetworkManaging) {
        self.networkManagerProvider = networkManagerProvider
    }

    func load() async {
        isLoading = true
        message = nil
        defer { isLoading = false }

        do {
            let networkManager = try networkManagerProvider()
            let response: OrdersResponseDTO = try await networkManager.request(OrderRouter.list)
            orders = response.data
        } catch {
            message = NetworkErrorMapper.userMessage(from: error, fallback: "주문 내역을 불러오지 못했습니다.")
        }
    }
}
