//
//  SearchViewModel.swift
//  Ditto
//
//  Created by Codex on 4/28/26.
//

import Foundation
import Observation

struct SearchActivity: Identifiable {
    let id: String
    let title: String
    let countryName: String?
    let latitude: Double?
    let longitude: Double?
    var location: String
    let status: String
    let statusDetail: String
    let summary: String
    let originalPrice: String?
    let finalPrice: String
    let discountRate: String?
    let keepCount: String
    let pointText: String
    let fallbackImageName: String
    let imageRequest: URLRequest?
    let isAdvertisement: Bool
    let isKeep: Bool
}

@MainActor
@Observable
final class SearchViewModel {
    private(set) var recommendedActivities: [SearchActivity] = []
    private(set) var categoryActivities: [SearchActivity] = []
    private(set) var nearbyActivities: [SearchActivity] = []
    private(set) var isLoadingRecommendedActivities = false
    private(set) var isLoadingCategoryActivities = false
    private(set) var isLoadingNearbyActivities = false
    private(set) var recommendedActivitiesMessage: String?
    private(set) var categoryActivitiesMessage: String?
    private(set) var nearbyActivitiesMessage: String?

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

    func loadRecommendedActivities() async {
        isLoadingRecommendedActivities = true
        recommendedActivitiesMessage = nil
        defer {
            isLoadingRecommendedActivities = false
        }

        do {
            let networkManager = try networkManagerProvider()
            let configuration = try configurationProvider()
            let query = ActivityPreviewQuery(country: nil, category: nil)
            let response: ActivitySummaryArrayResponseDTO = try await networkManager.request(ActivityRouter.new(query))
            recommendedActivities = mapActivities(response.data, configuration: configuration)

            if recommendedActivities.isEmpty {
                recommendedActivitiesMessage = "추천 액티비티가 없습니다."
            } else {
                scheduleCityNameResolution(for: recommendedActivities, target: .recommended)
            }
        } catch {
            recommendedActivitiesMessage = Self.makeErrorMessage(from: error)
        }
    }

    // category가 nil이면 카테고리 필터 없이 전체 액티비티를 가져온다.
    func loadCategoryActivities(category: String?) async {
        isLoadingCategoryActivities = true
        categoryActivitiesMessage = nil
        defer {
            isLoadingCategoryActivities = false
        }

        do {
            let networkManager = try networkManagerProvider()
            let configuration = try configurationProvider()
            let query = ActivityListQuery(country: nil, category: category, limit: 20, next: nil)
            let response: ActivitySummaryListResponseDTO = try await networkManager.request(ActivityRouter.list(query))
            categoryActivities = mapActivities(response.data, configuration: configuration)

            if categoryActivities.isEmpty {
                let label = category ?? "전체"
                categoryActivitiesMessage = "\(label) 액티비티가 없습니다."
            } else {
                scheduleCityNameResolution(for: categoryActivities, target: .category)
            }
        } catch {
            categoryActivitiesMessage = Self.makeErrorMessage(from: error)
        }
    }

    func loadNearbyActivities(coordinate: UserCoordinate?, maxDistanceMeters: Int?) async {
        isLoadingNearbyActivities = true
        nearbyActivitiesMessage = nil
        defer {
            isLoadingNearbyActivities = false
        }

        guard let coordinate else {
            nearbyActivities = []
            nearbyActivitiesMessage = "위치 권한을 허용하면 거리 기반 액티비티를 볼 수 있습니다."
            return
        }

        do {
            let networkManager = try networkManagerProvider()
            let configuration = try configurationProvider()
            let query = PostGeolocationQuery(
                country: nil,
                category: nil,
                longitude: coordinate.longitude,
                latitude: coordinate.latitude,
                maxDistance: maxDistanceMeters,
                limit: 30,
                next: nil,
                orderBy: .createdAt
            )
            let response: PostSummaryPaginationResponseDTO = try await networkManager.request(
                PostRouter.geolocation(query)
            )

            // 같은 액티비티가 여러 포스트에 묶여 있을 수 있어 id 기준으로 중복 제거한다.
            var seenIds = Set<String>()
            let uniqueActivities = response.data.compactMap { post -> ActivitySummaryPostResponseDTO? in
                guard let activity = post.activity else { return nil }
                return seenIds.insert(activity.id).inserted ? activity : nil
            }

            nearbyActivities = uniqueActivities.enumerated().map { index, activity in
                Self.makeNearbyActivity(
                    from: activity,
                    fallbackIndex: index,
                    configuration: configuration,
                    accessToken: authManager?.tokens?.accessToken
                )
            }

            if nearbyActivities.isEmpty {
                nearbyActivitiesMessage = "근처에 액티비티가 없습니다. 거리를 늘려 보세요."
            } else {
                scheduleCityNameResolution(for: nearbyActivities, target: .nearby)
            }
        } catch {
            nearbyActivitiesMessage = Self.makeErrorMessage(from: error)
        }
    }

    private func mapActivities(
        _ responses: [ActivitySummaryResponseDTO],
        configuration: AppConfiguration
    ) -> [SearchActivity] {
        responses.enumerated().map { index, response in
            Self.makeActivity(
                from: response,
                fallbackIndex: index,
                configuration: configuration,
                accessToken: authManager?.tokens?.accessToken
            )
        }
    }

    // 도시명 reverse geocoding 결과를 비동기로 받아 카드의 location을 "국가, 도시" 형태로 갱신한다.
    fileprivate func scheduleCityNameResolution(
        for snapshot: [SearchActivity],
        target: SearchActivityListTarget
    ) {
        Task { [weak self] in
            await self?.resolveCityNames(for: snapshot, target: target)
        }
    }

    fileprivate func resolveCityNames(
        for snapshot: [SearchActivity],
        target: SearchActivityListTarget
    ) async {
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
            switch target {
            case .recommended:
                if let index = recommendedActivities.firstIndex(where: { $0.id == activity.id }) {
                    recommendedActivities[index].location = combined
                }
            case .category:
                if let index = categoryActivities.firstIndex(where: { $0.id == activity.id }) {
                    categoryActivities[index].location = combined
                }
            case .nearby:
                if let index = nearbyActivities.firstIndex(where: { $0.id == activity.id }) {
                    nearbyActivities[index].location = combined
                }
            }
        }
    }
}

enum SearchActivityListTarget {
    case recommended
    case category
    case nearby
}

private extension SearchViewModel {
    static func makeActivity(
        from response: ActivitySummaryResponseDTO,
        fallbackIndex: Int,
        configuration: AppConfiguration,
        accessToken: String?
    ) -> SearchActivity {
        let fallback = fallbackImageNames[fallbackIndex % fallbackImageNames.count]
        let originalPrice = response.price.original
        let finalPrice = response.price.final
        let discountRate = makeDiscountRate(originalPrice: originalPrice, finalPrice: finalPrice)

        return SearchActivity(
            id: response.activityId,
            title: response.title.flatMap { $0.isEmpty ? nil : $0 } ?? "제목 없는 액티비티",
            countryName: response.country,
            latitude: response.geolocation.latitude,
            longitude: response.geolocation.longitude,
            location: ActivityFormatting.makeLocationText(country: response.country),
            status: makeStatus(isAdvertisement: response.isAdvertisement),
            statusDetail: makeStatusDetail(isAdvertisement: response.isAdvertisement),
            summary: makeSummary(tags: response.tags, category: response.category),
            originalPrice: discountRate == nil ? nil : ActivityFormatting.makePriceText(originalPrice),
            finalPrice: ActivityFormatting.makePriceText(finalPrice),
            discountRate: discountRate,
            keepCount: "\(response.keepCount)개",
            pointText: makePointText(response.pointReward),
            fallbackImageName: fallback,
            imageRequest: ActivityFormatting.makeImageRequest(
                from: ActivityFormatting.firstImageThumbnail(from: response.thumbnails),
                configuration: configuration,
                accessToken: accessToken
            ),
            isAdvertisement: response.isAdvertisement,
            isKeep: response.isKeep
        )
    }

    static func makeNearbyActivity(
        from response: ActivitySummaryPostResponseDTO,
        fallbackIndex: Int,
        configuration: AppConfiguration,
        accessToken: String?
    ) -> SearchActivity {
        let fallback = fallbackImageNames[fallbackIndex % fallbackImageNames.count]
        let originalPrice = response.price.original
        let finalPrice = response.price.final
        let discountRate = makeDiscountRate(originalPrice: originalPrice, finalPrice: finalPrice)

        return SearchActivity(
            id: response.id,
            title: response.title.flatMap { $0.isEmpty ? nil : $0 } ?? "제목 없는 액티비티",
            countryName: response.country,
            latitude: response.geolocation.latitude,
            longitude: response.geolocation.longitude,
            location: ActivityFormatting.makeLocationText(country: response.country),
            status: makeStatus(isAdvertisement: response.isAdvertisement),
            statusDetail: makeStatusDetail(isAdvertisement: response.isAdvertisement),
            summary: makeSummary(tags: response.tags, category: response.category),
            originalPrice: discountRate == nil ? nil : ActivityFormatting.makePriceText(originalPrice),
            finalPrice: ActivityFormatting.makePriceText(finalPrice),
            discountRate: discountRate,
            keepCount: "\(response.keepCount)개",
            pointText: makePointText(response.pointReward),
            fallbackImageName: fallback,
            imageRequest: ActivityFormatting.makeImageRequest(
                from: ActivityFormatting.firstImageThumbnail(from: response.thumbnails),
                configuration: configuration,
                accessToken: accessToken
            ),
            isAdvertisement: response.isAdvertisement,
            isKeep: response.isKeep
        )
    }

    static var fallbackImageNames: [String] {
        [
            "FigmaMainNewActivity2",
            "FigmaMainNewActivity1",
            "FigmaMainNewActivity3",
            "MainStoryParaglide"
        ]
    }

    static func makeStatus(isAdvertisement: Bool) -> String {
        isAdvertisement ? "NEW" : "HOT"
    }

    static func makeStatusDetail(isAdvertisement: Bool) -> String {
        isAdvertisement ? "액티비티 오픈할인" : "인기 액티비티"
    }

    static func makeSummary(tags: [String], category: String?) -> String {
        if !tags.isEmpty {
            return tags.joined(separator: " · ")
        }

        return "\(category ?? "새로운") 액티비티를 지금 확인해 보세요."
    }

    static func makePointText(_ pointReward: Double?) -> String {
        guard let pointReward else {
            return "0P"
        }

        return "\(Int(pointReward.rounded()))P"
    }

    static func makeDiscountRate(originalPrice: Double, finalPrice: Double) -> String? {
        guard originalPrice > finalPrice, originalPrice > 0 else {
            return nil
        }

        let discount = ((originalPrice - finalPrice) / originalPrice * 100).rounded()
        return "\(Int(discount))%"
    }

    static func makeErrorMessage(from error: Error) -> String {
        switch error {
        case let error as NetworkError:
            return makeNetworkErrorMessage(from: error)
        case AppConfigurationError.missingValue, AppConfigurationError.invalidURL:
            return "API 설정값을 확인해 주세요."
        default:
            return "액티비티를 불러오지 못했습니다."
        }
    }

    static func makeNetworkErrorMessage(from error: NetworkError) -> String {
        switch error {
        case .missingAuthenticationToken:
            return "로그인이 필요합니다."
        case .statusCode(_, let message, _):
            return message ?? "액티비티를 불러오지 못했습니다."
        case .requestFailed:
            return "네트워크 연결을 확인해 주세요."
        case .decodingFailed:
            return "액티비티를 불러오지 못했습니다."
        case .invalidURL:
            return "요청 주소가 올바르지 않습니다."
        case .invalidResponse:
            return "서버 응답을 확인할 수 없습니다."
        case .encodingFailed:
            return "요청 데이터를 만들 수 없습니다."
        }
    }
}

