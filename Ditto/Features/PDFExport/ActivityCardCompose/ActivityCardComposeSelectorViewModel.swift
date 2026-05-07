//
//  ActivityCardComposeSelectorViewModel.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import Foundation
import Observation

// 액티비티 카드 만들기 — 활동 선택 단계 ViewModel.
// 사용자의 주문 목록을 받아와 multi-select 상태를 관리한다.
@MainActor
@Observable
final class ActivityCardComposeSelectorViewModel {
    private(set) var orders: [OrderReviewResponseDTO] = []
    private(set) var isLoading = false
    var message: String?
    var selectedOrderIds: Set<String> = []

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

    var hasSelection: Bool {
        !selectedOrderIds.isEmpty
    }

    var selectedOrders: [OrderReviewResponseDTO] {
        orders.filter { selectedOrderIds.contains($0.orderId) }
    }

    func toggle(_ order: OrderReviewResponseDTO) {
        if selectedOrderIds.contains(order.orderId) {
            selectedOrderIds.remove(order.orderId)
        } else {
            selectedOrderIds.insert(order.orderId)
        }
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
