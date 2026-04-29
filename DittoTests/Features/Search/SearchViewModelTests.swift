//
//  SearchViewModelTests.swift
//  DittoTests
//
//  Created by Codex on 4/28/26.
//

import Foundation
import Testing
@testable import Ditto

@MainActor
struct SearchViewModelTests {
    @Test func loadRecommendedActivitiesUsesNewActivityRouterWithoutFilters() async throws {
        let networkManager = StubSearchNetworkManager()
        let viewModel = SearchViewModel(
            networkManager: networkManager,
            configuration: try makeConfiguration(),
            authManager: StubSearchAuthManager()
        )

        await viewModel.loadRecommendedActivities()

        let router = try #require(networkManager.requestedRouter as? ActivityRouter)

        if case .new(let query) = router {
            #expect(query.country == nil)
            #expect(query.category == nil)
        } else {
            #expect(Bool(false))
        }
    }

    @Test func loadCategoryActivitiesUsesListRouterWithSelectedCategory() async throws {
        let networkManager = StubSearchNetworkManager()
        let viewModel = SearchViewModel(
            networkManager: networkManager,
            configuration: try makeConfiguration(),
            authManager: StubSearchAuthManager()
        )

        await viewModel.loadCategoryActivities(category: "익사이팅")

        let router = try #require(networkManager.requestedRouter as? ActivityRouter)

        if case .list(let query) = router {
            #expect(query.country == nil)
            #expect(query.category == "익사이팅")
            #expect(query.limit == 20)
            #expect(query.next == nil)
        } else {
            #expect(Bool(false))
        }
    }

    @Test func loadCategoryActivitiesMapsActivitySummaryToSearchActivity() async throws {
        let networkManager = StubSearchNetworkManager()
        let viewModel = SearchViewModel(
            networkManager: networkManager,
            configuration: try makeConfiguration(),
            authManager: StubSearchAuthManager()
        )

        await viewModel.loadCategoryActivities(category: "익사이팅")

        let activity = try #require(viewModel.categoryActivities.first)
        #expect(activity.id == "activity-id")
        #expect(activity.location == "대한민국, 익사이팅")
        #expect(activity.title == "새싹 패러글라이딩 2기")
        #expect(activity.summary == "하늘 · 오픈특가")
        #expect(activity.originalPrice == "300,000원")
        #expect(activity.finalPrice == "210,000원")
        #expect(activity.discountRate == "30%")
        #expect(activity.keepCount == "48개")
        #expect(activity.pointText == "120P")
        #expect(activity.imageRequest?.url == URL(string: "https://example.com/v1/data/activities/paragliding.jpg"))
        #expect(activity.imageRequest?.value(forHTTPHeaderField: "SeSACKey") == "api-key")
        #expect(activity.imageRequest?.value(forHTTPHeaderField: "Authorization") == "access-token")
        #expect(activity.isAdvertisement)
        #expect(activity.isKeep)
    }

    @Test func loadRecommendedActivitiesShowsEmptyMessageWhenResponseIsEmpty() async throws {
        let networkManager = StubSearchNetworkManager(
            recommendedResponse: ActivitySummaryArrayResponseDTO(data: [])
        )
        let viewModel = SearchViewModel(
            networkManager: networkManager,
            configuration: try makeConfiguration(),
            authManager: StubSearchAuthManager()
        )

        await viewModel.loadRecommendedActivities()

        #expect(viewModel.recommendedActivities.isEmpty)
        #expect(viewModel.recommendedActivitiesMessage == "추천 액티비티가 없습니다.")
    }

    private func makeConfiguration() throws -> AppConfiguration {
        try AppConfiguration(baseURL: URL(string: "https://example.com")!, apiKey: "api-key")
    }
}

@MainActor
private final class StubSearchNetworkManager: NetworkManaging {
    private(set) var requestedRouter: APIRouter?
    private let recommendedResponse: ActivitySummaryArrayResponseDTO
    private let categoryResponse: ActivitySummaryListResponseDTO

    init(
        recommendedResponse: ActivitySummaryArrayResponseDTO = .dummy,
        categoryResponse: ActivitySummaryListResponseDTO = .dummy
    ) {
        self.recommendedResponse = recommendedResponse
        self.categoryResponse = categoryResponse
    }

    func request<T: Decodable>(_ router: APIRouter) async throws -> T {
        requestedRouter = router

        guard let activityRouter = router as? ActivityRouter else {
            throw StubSearchNetworkError.typeMismatch
        }

        switch activityRouter {
        case .new:
            guard let response = recommendedResponse as? T else {
                throw StubSearchNetworkError.typeMismatch
            }
            return response
        case .list:
            guard let response = categoryResponse as? T else {
                throw StubSearchNetworkError.typeMismatch
            }
            return response
        case .uploadFiles, .create, .detail, .update, .keep, .search, .myKeeps:
            throw StubSearchNetworkError.typeMismatch
        }
    }

    func send(_ router: APIRouter) async throws {
        requestedRouter = router
    }
}

@MainActor
private final class StubSearchAuthManager: AuthManaging {
    private(set) var tokens: AuthTokens? = AuthTokens(accessToken: "access-token", refreshToken: "refresh-token")

    var isAuthenticated: Bool {
        tokens != nil
    }

    func authenticate(with tokens: AuthTokens) throws {
        self.tokens = tokens
    }

    func signOut() throws {
        tokens = nil
    }
}

private extension ActivitySummaryArrayResponseDTO {
    static let dummy = ActivitySummaryArrayResponseDTO(
        data: [.dummy]
    )
}

private extension ActivitySummaryListResponseDTO {
    static let dummy = ActivitySummaryListResponseDTO(
        data: [.dummy],
        nextCursor: "0"
    )
}

private extension ActivitySummaryResponseDTO {
    static let dummy = ActivitySummaryResponseDTO(
        activityId: "activity-id",
        title: "새싹 패러글라이딩 2기",
        country: "대한민국",
        category: "익사이팅",
        thumbnails: [
            "/data/activities/preview.mp4",
            "/data/activities/paragliding.jpg"
        ],
        geolocation: ActivityGeolocationDTO(longitude: 127.0, latitude: 37.5),
        price: ActivityPriceDTO(original: 300_000, final: 210_000),
        tags: ["하늘", "오픈특가"],
        pointReward: 120,
        isAdvertisement: true,
        isKeep: true,
        keepCount: 48
    )
}

private enum StubSearchNetworkError: Error {
    case typeMismatch
}
