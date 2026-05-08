//
//  MainViewModel.swift
//  Ditto
//
//  Created by Codex on 4/27/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class MainViewModel {
    private(set) var newActivities: [MainNewActivity] = []
    private(set) var isLoadingNewActivities = false
    private(set) var newActivitiesMessage: String?
    private(set) var mainBanners: [MainBanner] = []
    private(set) var isLoadingMainBanners = false
    private(set) var mainBannersMessage: String?
    private(set) var activityPosts: [MainActivityPost] = []
    private(set) var isLoadingActivityPosts = false
    private(set) var activityPostsMessage: String?
    // 액티비티 포스트 무한 스크롤용 cursor. nil이면 추가 페이지가 없거나 아직 첫 로드 전.
    private(set) var activityPostsNextCursor: String?
    private(set) var isLoadingMoreActivityPosts = false
    private(set) var homeRecommendations: [MainNewActivity] = []
    private(set) var isLoadingHomeRecommendations = false
    private(set) var homeRecommendationsMessage: String?
    private(set) var chatStartMessage: String?

    // 화면 재진입 시 동일 조건의 NEW 액티비티를 다시 fetch하지 않도록 마지막 query key를 보관한다.
    @ObservationIgnored private var lastNewActivitiesQueryKey: String?

    // 피드 카드의 댓글 갯수를 위해 한 번 fetch한 결과를 저장. 같은 글 다시 prefetch 시 skip.
    @ObservationIgnored private var commentCountFetchedPostIds: Set<String> = []

    private let networkManagerProvider: @MainActor () throws -> any NetworkManaging
    private let configurationProvider: @MainActor () throws -> AppConfiguration
    private let authManager: (any AuthManaging)?

    internal convenience init(authManager: any AuthManaging) {
        self.init(
            networkManagerProvider: {
                let configuration = try AppConfiguration()
                return NetworkManager(configuration: configuration, authManager: authManager)
            },
            configurationProvider: {
                try AppConfiguration()
            },
            authManager: authManager
        )
    }

    internal init(
        networkManagerProvider: @escaping @MainActor () throws -> any NetworkManaging,
        configurationProvider: @escaping @MainActor () throws -> AppConfiguration,
        authManager: (any AuthManaging)?
    ) {
        self.networkManagerProvider = networkManagerProvider
        self.configurationProvider = configurationProvider
        self.authManager = authManager
    }

    internal convenience init(
        networkManager: any NetworkManaging,
        configuration: AppConfiguration,
        authManager: any AuthManaging
    ) {
        // 테스트에서는 실제 URLSession 대신 StubNetworkManager를 주입해 API 호출 흐름만 검증한다.
        self.init(
            networkManagerProvider: {
                networkManager
            },
            configurationProvider: {
                configuration
            },
            authManager: authManager
        )
    }

    func loadNewActivities(country: String?, category: String?) async {
        // 동일한 country/category 조합이면 상세 화면 왕복 등 view 재진입 시 다시 fetch하지 않는다.
        // 카드 순서가 매 fetch마다 흔들리는 것을 방지하기 위해 캐시 키로 분기한다.
        let queryKey = "\(country ?? "")|\(category ?? "")"
        if queryKey == lastNewActivitiesQueryKey, !newActivities.isEmpty {
            return
        }

        isLoadingNewActivities = true
        newActivitiesMessage = nil
        defer {
            isLoadingNewActivities = false
        }

        do {
            let networkManager = try networkManagerProvider()
            let configuration = try configurationProvider()
            let query = ActivityPreviewQuery(country: country, category: category)
            let response: ActivitySummaryArrayResponseDTO = try await networkManager.request(ActivityRouter.new(query))
            let mappedActivities = response.data.enumerated().map { index, activity in
                Self.makeNewActivity(
                    from: activity,
                    fallbackIndex: index,
                    configuration: configuration,
                    accessToken: authManager?.tokens?.accessToken
                )
            }

            if mappedActivities.isEmpty {
                newActivities = []
                newActivitiesMessage = "선택한 조건의 NEW 액티비티가 없습니다."
            } else {
                newActivities = mappedActivities
                scheduleCityNameResolution(for: mappedActivities)
            }
            lastNewActivitiesQueryKey = queryKey
        } catch {
            newActivitiesMessage = Self.makeErrorMessage(from: error)
        }
    }

    func loadMainBanners() async {
        isLoadingMainBanners = true
        mainBannersMessage = nil
        defer {
            isLoadingMainBanners = false
        }

        do {
            let networkManager = try networkManagerProvider()
            let configuration = try configurationProvider()
            let response: BannerListResponseDTO = try await networkManager.request(BannerRouter.main)
            mainBanners = response.data.enumerated().map { index, banner in
                Self.makeMainBanner(
                    from: banner,
                    fallbackIndex: index,
                    configuration: configuration,
                    accessToken: authManager?.tokens?.accessToken
                )
            }

            if mainBanners.isEmpty {
                mainBannersMessage = "표시할 배너가 없습니다."
            }
        } catch {
            mainBannersMessage = Self.makeBannerErrorMessage(from: error)
        }
    }

    func loadActivityPosts(
        country: String?,
        category: String?,
        coordinate: UserCoordinate? = nil,
        maxDistanceMeters: Int? = nil,
        orderBy: PostOrderBy = .createdAt,
        limit: Int = 20
    ) async {
        isLoadingActivityPosts = true
        activityPostsMessage = nil
        defer {
            isLoadingActivityPosts = false
        }

        do {
            let networkManager = try networkManagerProvider()
            let configuration = try configurationProvider()
            let query = PostGeolocationQuery(
                country: country,
                category: category,
                longitude: coordinate?.longitude,
                latitude: coordinate?.latitude,
                maxDistance: coordinate == nil ? nil : maxDistanceMeters,
                limit: limit,
                next: nil,
                orderBy: orderBy
            )
            let response: PostSummaryPaginationResponseDTO = try await networkManager.request(
                PostRouter.geolocation(query)
            )
            let mappedPosts = response.data.enumerated().map { index, post in
                Self.makeActivityPost(
                    from: post,
                    fallbackIndex: index,
                    configuration: configuration,
                    accessToken: authManager?.tokens?.accessToken
                )
            }

            // 첫 페이지 호출이므로 cursor를 응답 기준으로 새로 설정한다. 빈 문자열은 더 이상 페이지가 없다는 신호로 nil 처리.
            activityPostsNextCursor = response.nextCursor.isEmpty ? nil : response.nextCursor

            if mappedPosts.isEmpty {
                activityPosts = []
                activityPostsMessage = "선택한 조건의 액티비티 포스트가 없습니다."
            } else {
                activityPosts = mappedPosts
                // 새 페이지 fetch 시 cache flag도 reset해 일괄 prefetch 시작.
                commentCountFetchedPostIds.removeAll()
                prefetchCommentCounts(for: mappedPosts.map(\.id))
            }
        } catch {
            activityPostsMessage = Self.makeActivityPostErrorMessage(from: error)
        }
    }

    // 무한 스크롤용 — 다음 페이지가 남아 있을 때만 호출되며, 결과를 기존 activityPosts 뒤에 append한다.
    // 첫 페이지 fetch와 동일한 country/category/orderBy/coordinate 조합을 호출자가 그대로 전달한다.
    func loadMoreActivityPosts(
        country: String?,
        category: String?,
        coordinate: UserCoordinate? = nil,
        maxDistanceMeters: Int? = nil,
        orderBy: PostOrderBy = .createdAt,
        limit: Int = 20
    ) async {
        // 동시 추가 fetch 방지 + 첫 로딩 중에는 더 가져오지 않는다.
        guard !isLoadingMoreActivityPosts, !isLoadingActivityPosts else { return }
        guard let cursor = activityPostsNextCursor, !cursor.isEmpty else { return }

        isLoadingMoreActivityPosts = true
        defer {
            isLoadingMoreActivityPosts = false
        }

        do {
            let networkManager = try networkManagerProvider()
            let configuration = try configurationProvider()
            let query = PostGeolocationQuery(
                country: country,
                category: category,
                longitude: coordinate?.longitude,
                latitude: coordinate?.latitude,
                maxDistance: coordinate == nil ? nil : maxDistanceMeters,
                limit: limit,
                next: cursor,
                orderBy: orderBy
            )
            let response: PostSummaryPaginationResponseDTO = try await networkManager.request(
                PostRouter.geolocation(query)
            )

            // 다음 페이지 cursor 갱신. 빈 문자열이면 끝.
            activityPostsNextCursor = response.nextCursor.isEmpty ? nil : response.nextCursor

            // append 시 fallbackIndex가 기존 카드들 뒤로 이어지도록 누적 카운트를 시작 인덱스로 사용한다.
            let baseIndex = activityPosts.count
            let mapped = response.data.enumerated().map { offset, post in
                Self.makeActivityPost(
                    from: post,
                    fallbackIndex: baseIndex + offset,
                    configuration: configuration,
                    accessToken: authManager?.tokens?.accessToken
                )
            }
            activityPosts.append(contentsOf: mapped)
            // 새로 받은 카드들에 대해서도 일괄 prefetch.
            prefetchCommentCounts(for: mapped.map(\.id))
        } catch {
            // 무한 스크롤 실패는 첫 로드 메시지를 덮지 않도록 별도 처리하지 않는다.
            // 사용자가 다시 끝에 도달하면 자동으로 재시도된다.
        }
    }

    func loadActivityPosts(country: String?, category: String?) async {
        await loadActivityPosts(
            country: country,
            category: category,
            coordinate: nil,
            maxDistanceMeters: nil
        )
    }

    // 피드 카드 onAppear 트리거. 한 번 fetch한 글은 다시 호출해도 즉시 빠져나온다.
    // 서버 PostSummary에 commentCount가 없어 detail 응답의 comments.count로 자체 카운팅한다.
    func prefetchCommentCount(forPostId postId: String) async {
        guard !commentCountFetchedPostIds.contains(postId) else { return }
        commentCountFetchedPostIds.insert(postId)
        await fetchAndApplyCommentCount(forPostId: postId)
    }

    // loadActivityPosts/loadMoreActivityPosts 직후 호출. 응답 받은 글들에 대해
    // 백그라운드 task로 일괄 prefetch 시작. onAppear 시점에 의존하지 않아 더 신뢰성이 높다.
    func prefetchCommentCounts(for postIds: [String]) {
        for postId in postIds {
            guard !commentCountFetchedPostIds.contains(postId) else { continue }
            commentCountFetchedPostIds.insert(postId)
            Task { [weak self] in
                await self?.fetchAndApplyCommentCount(forPostId: postId)
            }
        }
    }

    // PostDetail에서 댓글 작성/삭제 후 호출. cache flag와 무관하게 다시 fetch해 갱신한다.
    func refreshCommentCount(forPostId postId: String) async {
        commentCountFetchedPostIds.insert(postId)
        await fetchAndApplyCommentCount(forPostId: postId)
    }

    // PostDetailView에서 그 글의 commentCount를 이미 알고 있을 때 직접 동기화하는 fast-path.
    func updateCommentCount(forPostId postId: String, count: Int) {
        commentCountFetchedPostIds.insert(postId)
        if let idx = activityPosts.firstIndex(where: { $0.id == postId }) {
            activityPosts[idx].commentCount = count
        }
    }

    // PostDetail에서 글 삭제 성공 시 피드 리스트에서도 제거한다.
    func removeActivityPost(postId: String) {
        activityPosts.removeAll { $0.id == postId }
        commentCountFetchedPostIds.remove(postId)
    }

    private func fetchAndApplyCommentCount(forPostId postId: String) async {
        do {
            let networkManager = try networkManagerProvider()
            let response: PostResponseDTO = try await networkManager.request(
                PostRouter.detail(postId: postId)
            )
            if let idx = activityPosts.firstIndex(where: { $0.id == postId }) {
                activityPosts[idx].commentCount = response.comments.count
            }
        } catch {
            // 실패는 조용히 무시 — 다음 prefetch 시도에서 재시도되도록 cache flag만 풀어준다.
            commentCountFetchedPostIds.remove(postId)
        }
    }

    // 피드 카드의 하트 탭 시 호출. optimistic update(좋아요 상태 + 카운트) 후 실패 시 원상 복귀한다.
    func togglePostLike(postId: String) async {
        guard let index = activityPosts.firstIndex(where: { $0.id == postId }) else {
            return
        }
        let originalLike = activityPosts[index].isLiked
        let originalCount = activityPosts[index].likeCount
        let nextLike = !originalLike
        activityPosts[index].isLiked = nextLike
        activityPosts[index].likeCount = max(0, originalCount + (nextLike ? 1 : -1))

        do {
            let networkManager = try networkManagerProvider()
            let request = PostLikeRequestDTO(likeStatus: nextLike)
            let response: PostLikeResponseDTO = try await networkManager.request(
                PostRouter.like(postId: postId, request: request)
            )
            if let idx = activityPosts.firstIndex(where: { $0.id == postId }) {
                activityPosts[idx].isLiked = response.likeStatus
            }
        } catch {
            // 실패 시 원래 상태로 복귀
            if let idx = activityPosts.firstIndex(where: { $0.id == postId }) {
                activityPosts[idx].isLiked = originalLike
                activityPosts[idx].likeCount = originalCount
            }
        }
    }

    // 홈 본문 하단의 추천 row용. country/category 필터 없이 가져온다.
    // SearchView의 추천 라우터와 동일한 ActivityRouter.new(country:nil, category:nil) 호출이다.
    func loadHomeRecommendations() async {
        isLoadingHomeRecommendations = true
        homeRecommendationsMessage = nil
        defer {
            isLoadingHomeRecommendations = false
        }

        do {
            let networkManager = try networkManagerProvider()
            let configuration = try configurationProvider()
            let query = ActivityPreviewQuery(country: nil, category: nil)
            let response: ActivitySummaryArrayResponseDTO = try await networkManager.request(ActivityRouter.new(query))
            let mapped = response.data.enumerated().map { index, activity in
                Self.makeNewActivity(
                    from: activity,
                    fallbackIndex: index,
                    configuration: configuration,
                    accessToken: authManager?.tokens?.accessToken
                )
            }

            if mapped.isEmpty {
                homeRecommendations = []
                homeRecommendationsMessage = "추천 액티비티가 없습니다."
            } else {
                homeRecommendations = mapped
            }
        } catch {
            homeRecommendationsMessage = Self.makeErrorMessage(from: error)
        }
    }

    // 서버 로그아웃은 베스트 에포트 — 실패해도 로컬 토큰 삭제(authManager.signOut)를 가로막지 않는다.
    func performServerLogout() async {
        do {
            let networkManager = try networkManagerProvider()
            try await networkManager.send(AuthRouter.logout)
        } catch {
            // 네트워크 오류·토큰 만료 등으로 호출이 실패해도 로컬 로그아웃은 보장한다.
        }
    }

    func createChatRoom(opponentId: String) async -> ChatRoomResponseDTO? {
        chatStartMessage = nil

        do {
            let networkManager = try networkManagerProvider()
            let request = ChatRoomCreateRequestDTO(opponentId: opponentId)
            return try await networkManager.request(ChatRouter.createRoom(request))
        } catch {
            do {
                let networkManager = try networkManagerProvider()
                if let existingRoom = try await existingChatRoom(
                    opponentId: opponentId,
                    networkManager: networkManager
                ) {
                    return existingRoom
                }
            } catch {
                // 새 방 생성 실패 원인이 기존 방인 경우가 있어, 목록 조회 실패보다 원래 오류 메시지를 우선 보여준다.
            }

            chatStartMessage = Self.makeChatStartErrorMessage(from: error)
            return nil
        }
    }

    private func existingChatRoom(
        opponentId: String,
        networkManager: any NetworkManaging
    ) async throws -> ChatRoomResponseDTO? {
        let response: ChatRoomListResponseDTO = try await networkManager.request(ChatRouter.rooms)

        return response.data.first { room in
            room.participants.contains { participant in
                participant.userId == opponentId
            }
        }
    }

    // 도시명 reverse geocoding 결과를 비동기로 받아 카드의 location을 "국가, 도시" 형태로 갱신한다.
    // private(set) 상태인 newActivities를 직접 갱신해야 해서 클래스 본체에 둔다.
    func scheduleCityNameResolution(for snapshot: [MainNewActivity]) {
        Task { [weak self] in
            await self?.resolveCityNames(for: snapshot)
        }
    }

    func resolveCityNames(for snapshot: [MainNewActivity]) async {
        for activity in snapshot {
            guard
                let latitude = activity.latitude,
                let longitude = activity.longitude
            else { continue }

            guard let city = await CityResolver.shared.city(
                latitude: latitude,
                longitude: longitude
            ) else { continue }

            let combined = ActivityFormatting.combineCountryAndCity(country: activity.countryName, city: city)
            guard !combined.isEmpty else { continue }

            // 도시명을 받아오는 사이 배열이 갱신될 수 있어 ID로 다시 찾아 갱신한다.
            if let index = newActivities.firstIndex(where: { $0.id == activity.id }) {
                newActivities[index].location = combined
            }
        }
    }
}
