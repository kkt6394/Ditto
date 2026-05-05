//
//  ReviewListViewModel.swift
//  Ditto
//
//  Created by Codex on 5/4/26.
//

import Foundation
import Observation

// 액티비티 리뷰 목록 + 별점 요약 ViewModel.
// 무한 스크롤 도입 전이라 next 커서는 첫 페이지 로드 결과만 보존하고
// loadMore()를 호출했을 때만 다음 페이지를 가져온다.
@MainActor
@Observable
final class ReviewListViewModel {
    let activityId: String

    private(set) var reviews: [ReviewResponseDTO] = []
    private(set) var ratings: [ReviewRatingResponseDTO] = []
    private(set) var nextCursor: String?
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    var orderBy: ReviewOrderBy = .latest
    var message: String?

    private let networkManagerProvider: @MainActor () throws -> any NetworkManaging

    convenience init(activityId: String, authManager: any AuthManaging) {
        self.init(activityId: activityId) {
            let configuration = try AppConfiguration()
            return NetworkManager(configuration: configuration, authManager: authManager)
        }
    }

    init(
        activityId: String,
        networkManagerProvider: @escaping @MainActor () throws -> any NetworkManaging
    ) {
        self.activityId = activityId
        self.networkManagerProvider = networkManagerProvider
    }

    func loadFirstPage() async {
        isLoading = true
        message = nil
        defer { isLoading = false }

        do {
            let networkManager = try networkManagerProvider()
            async let listTask: ReviewListResponseDTO = networkManager.request(
                ReviewRouter.list(ReviewListQuery(activityId: activityId, next: nil, limit: nil, orderBy: orderBy))
            )
            async let ratingsTask: ReviewRatingListResponseDTO = networkManager.request(
                ReviewRouter.ratingSummary(activityId: activityId)
            )
            let list = try await listTask
            let ratingResponse = try await ratingsTask

            reviews = list.data
            nextCursor = list.nextCursor.isEmpty ? nil : list.nextCursor
            ratings = ratingResponse.data
        } catch {
            message = NetworkErrorMapper.userMessage(from: error, fallback: "리뷰를 불러오지 못했습니다.")
        }
    }

    func loadMore() async {
        guard let cursor = nextCursor, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let networkManager = try networkManagerProvider()
            let response: ReviewListResponseDTO = try await networkManager.request(
                ReviewRouter.list(ReviewListQuery(activityId: activityId, next: cursor, limit: nil, orderBy: orderBy))
            )
            reviews.append(contentsOf: response.data)
            nextCursor = response.nextCursor.isEmpty ? nil : response.nextCursor
        } catch {
            message = NetworkErrorMapper.userMessage(from: error, fallback: "리뷰를 더 불러오지 못했습니다.")
        }
    }
}
