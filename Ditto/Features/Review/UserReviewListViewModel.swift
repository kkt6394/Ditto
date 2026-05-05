//
//  UserReviewListViewModel.swift
//  Ditto
//
//  Created by Codex on 5/4/26.
//

import Foundation
import Observation

// 사용자가 작성한 리뷰 목록 조회용 ViewModel.
@MainActor
@Observable
final class UserReviewListViewModel {
    let userId: String

    private(set) var reviews: [UserReviewResponseDTO] = []
    private(set) var nextCursor: String?
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    var country: String?
    var category: String?
    var message: String?

    private let networkManagerProvider: @MainActor () throws -> any NetworkManaging

    convenience init(userId: String, authManager: any AuthManaging) {
        self.init(userId: userId) {
            let configuration = try AppConfiguration()
            return NetworkManager(configuration: configuration, authManager: authManager)
        }
    }

    init(
        userId: String,
        networkManagerProvider: @escaping @MainActor () throws -> any NetworkManaging
    ) {
        self.userId = userId
        self.networkManagerProvider = networkManagerProvider
    }

    func loadFirstPage() async {
        isLoading = true
        message = nil
        defer { isLoading = false }

        do {
            let networkManager = try networkManagerProvider()
            let query = UserReviewListQuery(
                userId: userId,
                country: country,
                category: category,
                next: nil,
                limit: nil
            )
            let response: UserReviewListResponseDTO = try await networkManager.request(
                ReviewRouter.reviewsByUser(query)
            )
            reviews = response.data
            nextCursor = response.nextCursor.isEmpty ? nil : response.nextCursor
        } catch {
            message = NetworkErrorMapper.userMessage(from: error, fallback: "사용자 리뷰를 불러오지 못했습니다.")
        }
    }

    func loadMore() async {
        guard let cursor = nextCursor, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let networkManager = try networkManagerProvider()
            let query = UserReviewListQuery(
                userId: userId,
                country: country,
                category: category,
                next: cursor,
                limit: nil
            )
            let response: UserReviewListResponseDTO = try await networkManager.request(
                ReviewRouter.reviewsByUser(query)
            )
            reviews.append(contentsOf: response.data)
            nextCursor = response.nextCursor.isEmpty ? nil : response.nextCursor
        } catch {
            message = NetworkErrorMapper.userMessage(from: error, fallback: "사용자 리뷰를 더 불러오지 못했습니다.")
        }
    }
}
