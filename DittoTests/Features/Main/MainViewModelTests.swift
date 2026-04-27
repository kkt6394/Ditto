//
//  MainViewModelTests.swift
//  DittoTests
//
//  Created by Codex on 4/27/26.
//

import Foundation
import Testing
@testable import Ditto

@MainActor
struct MainViewModelTests {
    @Test func loadNewActivitiesSendsNewActivityRouterWithSelectedFilters() async throws {
        let networkManager = StubMainNetworkManager()
        let viewModel = MainViewModel(
            networkManager: networkManager,
            configuration: try makeConfiguration(),
            authManager: StubMainAuthManager()
        )

        await viewModel.loadNewActivities(country: "대한민국", category: "투어")

        let router = try #require(networkManager.requestedRouter as? ActivityRouter)

        if case .new(let query) = router {
            #expect(query.country == "대한민국")
            #expect(query.category == "투어")
        } else {
            #expect(Bool(false))
        }
    }

    @Test func loadNewActivitiesMapsSummaryResponseToMainActivity() async throws {
        let networkManager = StubMainNetworkManager()
        let viewModel = MainViewModel(
            networkManager: networkManager,
            configuration: try makeConfiguration(),
            authManager: StubMainAuthManager()
        )

        await viewModel.loadNewActivities(country: "대한민국", category: "투어")

        let activity = try #require(viewModel.newActivities.first)
        #expect(activity.id == "activity-id")
        #expect(activity.location == "대한민국, 투어")
        #expect(activity.title == "서울 야경 투어")
        #expect(activity.price == "128,000원")
        #expect(activity.summary == "야경 · 신규")
        #expect(activity.imageRequest?.url == URL(string: "https://example.com/v1/data/activities/seoul.jpg"))
        #expect(activity.imageRequest?.value(forHTTPHeaderField: "SeSACKey") == "api-key")
        #expect(activity.imageRequest?.value(forHTTPHeaderField: "Authorization") == "access-token")
    }

    @Test func loadNewActivitiesSkipsVideoThumbnailAndUsesFirstImageThumbnail() async throws {
        let networkManager = StubMainNetworkManager(
            result: .success(.withVideoFirstThumbnail)
        )
        let viewModel = MainViewModel(
            networkManager: networkManager,
            configuration: try makeConfiguration(),
            authManager: StubMainAuthManager()
        )

        await viewModel.loadNewActivities(country: "일본", category: "익사이팅")

        let activity = try #require(viewModel.newActivities.first)
        #expect(activity.imageRequest?.url == URL(string: "https://example.com/v1/data/activities/activity_52.jpg"))
    }

    @Test func loadNewActivitiesShowsNetworkErrorMessageOnFailure() async throws {
        let networkManager = StubMainNetworkManager(
            result: .failure(NetworkError.statusCode(401, message: "로그인이 필요합니다.", data: Data()))
        )
        let viewModel = MainViewModel(
            networkManager: networkManager,
            configuration: try makeConfiguration(),
            authManager: StubMainAuthManager()
        )

        await viewModel.loadNewActivities(country: "대한민국", category: "투어")

        #expect(viewModel.newActivitiesMessage == "로그인이 필요합니다.")
    }

    @Test func loadNewActivitiesClearsItemsAndShowsEmptyMessageWhenResponseIsEmpty() async throws {
        let networkManager = StubMainNetworkManager(result: .success(ActivitySummaryArrayResponseDTO(data: [])))
        let viewModel = MainViewModel(
            networkManager: networkManager,
            configuration: try makeConfiguration(),
            authManager: StubMainAuthManager()
        )

        await viewModel.loadNewActivities(country: "호주", category: "투어")

        #expect(viewModel.newActivities.isEmpty)
        #expect(viewModel.newActivitiesMessage == "선택한 조건의 NEW 액티비티가 없습니다.")
    }

    private func makeConfiguration() throws -> AppConfiguration {
        try AppConfiguration(baseURL: URL(string: "https://example.com")!, apiKey: "api-key")
    }
}

@MainActor
private final class StubMainNetworkManager: NetworkManaging {
    private(set) var requestedRouter: APIRouter?
    private let result: Result<ActivitySummaryArrayResponseDTO, Error>

    init(result: Result<ActivitySummaryArrayResponseDTO, Error> = .success(.dummy)) {
        self.result = result
    }

    func request<T: Decodable>(_ router: APIRouter) async throws -> T {
        requestedRouter = router

        switch result {
        case .success(let response):
            guard let typedResponse = response as? T else {
                throw StubMainNetworkError.typeMismatch
            }
            return typedResponse
        case .failure(let error):
            throw error
        }
    }

    func send(_ router: APIRouter) async throws {
        requestedRouter = router
    }
}

@MainActor
private final class StubMainAuthManager: AuthManaging {
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
        data: [
            ActivitySummaryResponseDTO(
                activityId: "activity-id",
                title: "서울 야경 투어",
                country: "대한민국",
                category: "투어",
                thumbnails: ["/data/activities/seoul.jpg"],
                geolocation: ActivityGeolocationDTO(longitude: 127.0, latitude: 37.5),
                price: ActivityPriceDTO(original: 150_000, final: 128_000),
                tags: ["야경", "신규"],
                pointReward: 100,
                isAdvertisement: false,
                isKeep: false,
                keepCount: 12
            )
        ]
    )

    static let withVideoFirstThumbnail = ActivitySummaryArrayResponseDTO(
        data: [
            ActivitySummaryResponseDTO(
                activityId: "activity-id",
                title: "브랜님의 스키 익사이팅",
                country: "일본",
                category: "익사이팅",
                thumbnails: [
                    "/data/activities/activity_7.mp4",
                    "/data/activities/activity_52.jpg",
                    "/data/activities/activity_25.jpg"
                ],
                geolocation: ActivityGeolocationDTO(longitude: 140.687355, latitude: 42.804848),
                price: ActivityPriceDTO(original: 950, final: 780),
                tags: [],
                pointReward: 78,
                isAdvertisement: true,
                isKeep: false,
                keepCount: 1
            )
        ]
    )
}

private enum StubMainNetworkError: Error {
    case typeMismatch
}
