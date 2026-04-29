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
    let location: String
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
    private(set) var isLoadingRecommendedActivities = false
    private(set) var isLoadingCategoryActivities = false
    private(set) var recommendedActivitiesMessage: String?
    private(set) var categoryActivitiesMessage: String?

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
            }
        } catch {
            recommendedActivitiesMessage = Self.makeErrorMessage(from: error)
        }
    }

    func loadCategoryActivities(category: String) async {
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
                categoryActivitiesMessage = "\(category) 액티비티가 없습니다."
            }
        } catch {
            categoryActivitiesMessage = Self.makeErrorMessage(from: error)
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
            location: makeLocationText(country: response.country, category: response.category),
            status: makeStatus(isAdvertisement: response.isAdvertisement),
            statusDetail: makeStatusDetail(isAdvertisement: response.isAdvertisement),
            summary: makeSummary(tags: response.tags, category: response.category),
            originalPrice: discountRate == nil ? nil : makePriceText(originalPrice),
            finalPrice: makePriceText(finalPrice),
            discountRate: discountRate,
            keepCount: "\(response.keepCount)개",
            pointText: makePointText(response.pointReward),
            fallbackImageName: fallback,
            imageRequest: makeImageRequest(
                from: firstImageThumbnail(from: response.thumbnails),
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

    static func makeLocationText(country: String?, category: String?) -> String {
        [country, category]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
            .ifEmpty("위치 정보 없음")
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

    static func makePriceText(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        let numberText = formatter.string(from: NSNumber(value: price)) ?? "\(Int(price))"
        return "\(numberText)원"
    }

    static func makeDiscountRate(originalPrice: Double, finalPrice: Double) -> String? {
        guard originalPrice > finalPrice, originalPrice > 0 else {
            return nil
        }

        let discount = ((originalPrice - finalPrice) / originalPrice * 100).rounded()
        return "\(Int(discount))%"
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

    static func isImagePath(_ path: String) -> Bool {
        let lowercasedPath = path.lowercased()

        return [".jpg", ".jpeg", ".png", ".webp"].contains { imageExtension in
            lowercasedPath.hasSuffix(imageExtension)
        }
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

private extension String {
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
