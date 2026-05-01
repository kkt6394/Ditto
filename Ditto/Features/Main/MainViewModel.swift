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
    private(set) var newActivities = MainNewActivity.samples
    private(set) var isLoadingNewActivities = false
    private(set) var newActivitiesMessage: String?
    private(set) var mainBanners: [MainBanner] = []
    private(set) var isLoadingMainBanners = false
    private(set) var mainBannersMessage: String?
    private(set) var activityPosts = MainActivityPost.samples
    private(set) var isLoadingActivityPosts = false
    private(set) var activityPostsMessage: String?
    private(set) var chatStartMessage: String?

    // 화면 재진입 시 동일 조건의 NEW 액티비티를 다시 fetch하지 않도록 마지막 query key를 보관한다.
    @ObservationIgnored private var lastNewActivitiesQueryKey: String?

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
        maxDistanceMeters: Int? = nil
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
                limit: 5,
                next: nil,
                orderBy: "createdAt"
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

            if mappedPosts.isEmpty {
                activityPosts = []
                activityPostsMessage = "선택한 조건의 액티비티 포스트가 없습니다."
            } else {
                activityPosts = mappedPosts
            }
        } catch {
            activityPostsMessage = Self.makeActivityPostErrorMessage(from: error)
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

    static func makeNewActivity(
        from response: ActivitySummaryResponseDTO,
        fallbackIndex: Int,
        configuration: AppConfiguration,
        accessToken: String?
    ) -> MainNewActivity {
        let fallback = MainNewActivity.samples[fallbackIndex % MainNewActivity.samples.count]
        let category = response.category ?? "액티비티"
        let title = response.title.flatMap { $0.isEmpty ? nil : $0 } ?? "제목 없는 액티비티"
        let summary = response.tags.isEmpty
            ? "새롭게 등록된 \(category) 액티비티입니다."
            : response.tags.joined(separator: " · ")

        return MainNewActivity(
            id: response.activityId,
            countryName: response.country,
            latitude: response.geolocation.latitude,
            longitude: response.geolocation.longitude,
            location: makeLocationText(country: response.country),
            title: title,
            price: makePriceText(response.price.final),
            summary: summary,
            imageName: fallback.imageName,
            imageRequest: makeImageRequest(
                from: firstImageThumbnail(from: response.thumbnails),
                configuration: configuration,
                accessToken: accessToken
            )
        )
    }

    static func makeErrorMessage(from error: Error) -> String {
        switch error {
        case let error as NetworkError:
            return makeNetworkErrorMessage(from: error)
        case AppConfigurationError.missingValue, AppConfigurationError.invalidURL:
            return "API 설정값을 확인해 주세요."
        default:
            return "NEW 액티비티를 불러오지 못했습니다."
        }
    }

    static func makeBannerErrorMessage(from error: Error) -> String {
        switch error {
        case let error as NetworkError:
            return makeNetworkErrorMessage(from: error, fallbackMessage: "배너를 불러오지 못했습니다.")
        case AppConfigurationError.missingValue, AppConfigurationError.invalidURL:
            return "API 설정값을 확인해 주세요."
        default:
            return "배너를 불러오지 못했습니다."
        }
    }

    static func makeMainBanner(
        from response: BannerResponseDTO,
        fallbackIndex: Int,
        configuration: AppConfiguration,
        accessToken: String?
    ) -> MainBanner {
        MainBanner(
            id: "\(response.payload.type)-\(response.payload.value)-\(fallbackIndex)",
            name: response.name,
            imageRequest: makeImageRequest(
                from: response.imageUrl,
                configuration: configuration,
                accessToken: accessToken
            ),
            payloadType: response.payload.type,
            payloadValue: response.payload.value
        )
    }

    static func makeActivityPost(
        from response: PostSummaryResponseDTO,
        fallbackIndex: Int,
        configuration: AppConfiguration,
        accessToken: String?
    ) -> MainActivityPost {
        let fallback = MainActivityPost.samples[fallbackIndex % MainActivityPost.samples.count]
        let imageRequests = imagePaths(from: response.files).map {
            makeImageRequest(from: $0, configuration: configuration, accessToken: accessToken)
        }

        return MainActivityPost(
            id: response.postId,
            activityId: response.activity?.id,
            creatorId: response.creator.userId,
            author: response.creator.nick,
            timeText: makeRelativeTimeText(from: response.createdAt),
            title: response.title,
            body: response.content,
            location: makeLocationText(country: response.country),
            category: response.activity?.title ?? response.category,
            profileImageName: fallback.profileImageName,
            profileImageRequest: makeImageRequest(
                from: response.creator.profileImage,
                configuration: configuration,
                accessToken: accessToken
            ),
            mainImageName: fallback.mainImageName,
            mainImageRequest: imageRequests[safe: 0] ?? nil,
            subImageTopName: fallback.subImageTopName,
            subImageTopRequest: imageRequests[safe: 1] ?? nil,
            subImageBottomName: fallback.subImageBottomName,
            subImageBottomRequest: imageRequests[safe: 2] ?? nil,
            media: makePostMedia(
                from: response.files,
                fallback: fallback,
                configuration: configuration,
                accessToken: accessToken
            ),
            isLiked: response.isLike
        )
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
}

private extension MainViewModel {
    // 도시명 reverse geocoding 결과를 비동기로 받아 카드의 location을 "국가, 도시" 형태로 갱신한다.
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

            let combined = Self.combineCountryAndCity(country: activity.countryName, city: city)
            guard !combined.isEmpty else { continue }

            // 도시명을 받아오는 사이 배열이 갱신될 수 있어 ID로 다시 찾아 갱신한다.
            if let index = newActivities.firstIndex(where: { $0.id == activity.id }) {
                newActivities[index].location = combined
            }
        }
    }

    static func combineCountryAndCity(country: String?, city: String) -> String {
        [country, city]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    static func makeLocationText(country: String?) -> String {
        (country ?? "")
            .ifEmpty("위치 정보 없음")
    }

    static func makePriceText(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        let numberText = formatter.string(from: NSNumber(value: price)) ?? "\(Int(price))"
        return "\(numberText)원"
    }

    static func makeImageRequest(
        from thumbnailPath: String?,
        configuration: AppConfiguration,
        accessToken: String?
    ) -> URLRequest? {
        guard let thumbnailPath, !thumbnailPath.isEmpty else {
            return nil
        }

        let imageURL: URL?

        if let url = URL(string: thumbnailPath), url.scheme != nil {
            imageURL = url
        } else {
            imageURL = makeImageURL(from: thumbnailPath, baseURL: configuration.baseURL)
        }

        guard let imageURL else {
            return nil
        }

        var request = URLRequest(url: imageURL)
        request.setValue(configuration.apiKey, forHTTPHeaderField: "SeSACKey")

        if let accessToken {
            request.setValue(accessToken, forHTTPHeaderField: "Authorization")
        }

        return request
    }

    static func firstImageThumbnail(from thumbnails: [String]) -> String? {
        thumbnails.first { thumbnail in
            isImagePath(thumbnail)
        }
    }

    static func imagePaths(from paths: [String]) -> [String] {
        paths.filter { isImagePath($0) }
    }

    static func makePostMedia(
        from paths: [String],
        fallback: MainActivityPost,
        configuration: AppConfiguration,
        accessToken: String?
    ) -> [MainPostMedia] {
        let fallbackNames = [
            fallback.mainImageName,
            fallback.subImageTopName,
            fallback.subImageBottomName
        ]

        let media = paths.enumerated().compactMap { index, path -> MainPostMedia? in
            let fallbackName = fallbackNames[index % fallbackNames.count]

            if isImagePath(path) {
                let request = makeImageRequest(from: path, configuration: configuration, accessToken: accessToken)
                return .image(id: "\(path)-\(index)", request: request, fallbackImageName: fallbackName)
            }

            if isVideoPath(path) {
                let videoId = videoId(from: path)
                let request = videoId == nil
                    ? makeImageRequest(from: path, configuration: configuration, accessToken: accessToken)
                    : nil

                return .video(
                    id: "\(path)-\(index)",
                    request: request,
                    fallbackImageName: fallbackName,
                    videoId: videoId
                )
            }

            return nil
        }

        if media.isEmpty {
            return fallback.media
        }

        return media
    }

    static func isImagePath(_ path: String) -> Bool {
        let lowercasedPath = path.lowercased()

        return [".jpg", ".jpeg", ".png", ".webp"].contains { imageExtension in
            lowercasedPath.hasSuffix(imageExtension)
        }
    }

    static func isVideoPath(_ path: String) -> Bool {
        let lowercasedPath = path.lowercased()

        if lowercasedPath.hasPrefix("video://") {
            return true
        }

        return [".mp4", ".mov", ".m4v", ".m3u8"].contains { videoExtension in
            lowercasedPath.hasSuffix(videoExtension)
        }
    }

    static func videoId(from path: String) -> String? {
        guard path.hasPrefix("video://") else {
            return nil
        }

        let videoId = String(path.dropFirst("video://".count))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return videoId.isEmpty ? nil : videoId
    }

    static func makeImageURL(from thumbnailPath: String, baseURL: URL) -> URL? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var imagePath = thumbnailPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if imagePath.hasPrefix("data/") {
            imagePath = "v1/" + imagePath
        }

        components.path = "/" + [basePath, imagePath]
            .filter { !$0.isEmpty }
            .joined(separator: "/")

        return components.url
    }

    static func makeNetworkErrorMessage(from error: NetworkError) -> String {
        makeNetworkErrorMessage(from: error, fallbackMessage: "NEW 액티비티를 불러오지 못했습니다.")
    }

    static func makeNetworkErrorMessage(from error: NetworkError, fallbackMessage: String) -> String {
        switch error {
        case .missingAuthenticationToken:
            return "로그인이 필요합니다."
        case .statusCode(_, let message, _):
            return message ?? fallbackMessage
        case .requestFailed:
            return "네트워크 연결을 확인해 주세요."
        case .decodingFailed:
            return fallbackMessage
        case .invalidURL:
            return "요청 주소가 올바르지 않습니다."
        case .invalidResponse:
            return "서버 응답을 확인할 수 없습니다."
        case .encodingFailed:
            return "요청 데이터를 만들 수 없습니다."
        }
    }

    static func makeActivityPostErrorMessage(from error: Error) -> String {
        switch error {
        case let error as NetworkError:
            return makeNetworkErrorMessage(from: error, fallbackMessage: "액티비티 포스트를 불러오지 못했습니다.")
        case AppConfigurationError.missingValue, AppConfigurationError.invalidURL:
            return "API 설정값을 확인해 주세요."
        default:
            return "액티비티 포스트를 불러오지 못했습니다."
        }
    }

    static func makeChatStartErrorMessage(from error: Error) -> String {
        switch error {
        case let error as NetworkError:
            return makeNetworkErrorMessage(from: error, fallbackMessage: "채팅방을 만들지 못했습니다.")
        case AppConfigurationError.missingValue, AppConfigurationError.invalidURL:
            return "API 설정값을 확인해 주세요."
        default:
            return "채팅방을 만들지 못했습니다."
        }
    }

    static func makeRelativeTimeText(from createdAt: String) -> String {
        guard let date = ISO8601DateFormatter.full.date(from: createdAt) else {
            return createdAt
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.unitsStyle = .full

        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private extension ISO8601DateFormatter {
    static let full: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        return formatter
    }()
}
