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

    @Test func loadActivityPostsSendsGeolocationRouterWithSelectedFilters() async throws {
        let networkManager = StubMainNetworkManager()
        let viewModel = MainViewModel(
            networkManager: networkManager,
            configuration: try makeConfiguration(),
            authManager: StubMainAuthManager()
        )

        await viewModel.loadActivityPosts(
            country: "대한민국",
            category: "관광",
            coordinate: UserCoordinate(latitude: 37.5, longitude: 127.0),
            maxDistanceMeters: 3_000
        )

        let router = try #require(networkManager.requestedRouter as? PostRouter)

        if case .geolocation(let query) = router {
            #expect(query.country == "대한민국")
            #expect(query.category == "관광")
            #expect(query.longitude == 127.0)
            #expect(query.latitude == 37.5)
            #expect(query.maxDistance == 3_000)
            #expect(query.limit == 5)
            #expect(query.orderBy == "createdAt")
        } else {
            #expect(Bool(false))
        }
    }

    @Test func loadActivityPostsMapsPostSummaryResponseToMainPost() async throws {
        let networkManager = StubMainNetworkManager()
        let viewModel = MainViewModel(
            networkManager: networkManager,
            configuration: try makeConfiguration(),
            authManager: StubMainAuthManager()
        )

        await viewModel.loadActivityPosts(country: "대한민국", category: "관광")

        let post = try #require(viewModel.activityPosts.first)
        #expect(post.id == "post-id")
        #expect(post.activityId == "activity-id")
        #expect(post.creatorId == "user-id")
        #expect(post.author == "새싹 여행자")
        #expect(post.title == "한강 러닝 후기")
        #expect(post.body == "오전 러닝 코스가 좋았습니다.")
        #expect(post.location == "대한민국")
        #expect(post.category == "한강 러닝 클래스")
        #expect(post.profileImageRequest?.url == URL(string: "https://example.com/v1/data/users/profile.jpg"))
        #expect(post.mainImageRequest?.url == URL(string: "https://example.com/v1/data/posts/main.jpg"))
        #expect(post.subImageTopRequest?.url == URL(string: "https://example.com/v1/data/posts/sub.jpg"))
        #expect(post.subImageBottomRequest == nil)
        #expect(post.media.count == 3)
        #expect(post.media[0].kind == .image)
        #expect(post.media[1].kind == .video)
        #expect(post.media[1].request?.url == URL(string: "https://example.com/v1/data/posts/video.mp4"))
        #expect(post.media[2].kind == .image)
        #expect(post.isLiked)
    }

    @Test func createChatRoomSendsChatRouterWithCreatorId() async throws {
        let networkManager = StubMainNetworkManager()
        let viewModel = MainViewModel(
            networkManager: networkManager,
            configuration: try makeConfiguration(),
            authManager: StubMainAuthManager()
        )

        let room = await viewModel.createChatRoom(opponentId: "user-id")
        let router = try #require(networkManager.requestedRouter as? ChatRouter)

        if case .createRoom(let request) = router {
            #expect(request.opponentId == "user-id")
        } else {
            #expect(Bool(false))
        }

        #expect(room?.roomId == "room-id")
    }

    private func makeConfiguration() throws -> AppConfiguration {
        try AppConfiguration(baseURL: URL(string: "https://example.com")!, apiKey: "api-key")
    }
}

@MainActor
private final class StubMainNetworkManager: NetworkManaging {
    private(set) var requestedRouter: APIRouter?
    private let result: Result<ActivitySummaryArrayResponseDTO, Error>
    private let postResult: Result<PostSummaryPaginationResponseDTO, Error>
    private let chatRoomResult: Result<ChatRoomResponseDTO, Error>

    init(
        result: Result<ActivitySummaryArrayResponseDTO, Error> = .success(.dummy),
        postResult: Result<PostSummaryPaginationResponseDTO, Error> = .success(.dummy),
        chatRoomResult: Result<ChatRoomResponseDTO, Error> = .success(.dummy)
    ) {
        self.result = result
        self.postResult = postResult
        self.chatRoomResult = chatRoomResult
    }

    func request<T: Decodable>(_ router: APIRouter) async throws -> T {
        requestedRouter = router

        if router is ActivityRouter {
            switch result {
            case .success(let response):
                guard let typedResponse = response as? T else {
                    throw StubMainNetworkError.typeMismatch
                }
                return typedResponse
            case .failure(let error):
                throw error
            }
        } else if router is PostRouter {
            switch postResult {
            case .success(let response):
                guard let typedResponse = response as? T else {
                    throw StubMainNetworkError.typeMismatch
                }
                return typedResponse
            case .failure(let error):
                throw error
            }
        } else if router is ChatRouter {
            switch chatRoomResult {
            case .success(let response):
                guard let typedResponse = response as? T else {
                    throw StubMainNetworkError.typeMismatch
                }
                return typedResponse
            case .failure(let error):
                throw error
            }
        } else {
            throw StubMainNetworkError.typeMismatch
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

private extension PostSummaryPaginationResponseDTO {
    static let dummy = PostSummaryPaginationResponseDTO(
        data: [
            PostSummaryResponseDTO(
                postId: "post-id",
                country: "대한민국",
                category: "관광",
                title: "한강 러닝 후기",
                content: "오전 러닝 코스가 좋았습니다.",
                activity: ActivitySummaryPostResponseDTO(
                    id: "activity-id",
                    title: "한강 러닝 클래스",
                    country: "대한민국",
                    category: "관광",
                    thumbnails: [],
                    geolocation: ActivityGeolocationDTO(longitude: 127.0, latitude: 37.5),
                    price: ActivityPriceDTO(original: 20_000, final: 15_000),
                    tags: [],
                    pointReward: nil,
                    isAdvertisement: false,
                    isKeep: false,
                    keepCount: 0
                ),
                geolocation: Geolocation(longitude: 127.0, latitude: 37.5),
                creator: UserInfoResponseDTO(
                    userId: "user-id",
                    nick: "새싹 여행자",
                    profileImage: "/data/users/profile.jpg",
                    introduction: nil
                ),
                files: [
                    "/data/posts/main.jpg",
                    "/data/posts/video.mp4",
                    "/data/posts/sub.jpg"
                ],
                isLike: true,
                likeCount: 12,
                createdAt: "2026-04-28T08:00:00.000Z",
                updatedAt: "2026-04-28T08:00:00.000Z"
            )
        ],
        nextCursor: "0"
    )
}

private extension ChatRoomResponseDTO {
    static let dummy = ChatRoomResponseDTO(
        roomId: "room-id",
        createdAt: "2026-04-28T08:00:00.000Z",
        updatedAt: "2026-04-28T08:00:00.000Z",
        participants: [
            UserInfoResponseDTO(
                userId: "user-id",
                nick: "새싹 여행자",
                profileImage: "/data/users/profile.jpg",
                introduction: nil
            )
        ],
        lastChat: nil
    )
}

private enum StubMainNetworkError: Error {
    case typeMismatch
}
