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
            }
        } catch {
            newActivitiesMessage = Self.makeErrorMessage(from: error)
        }
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
            location: makeLocationText(country: response.country, category: response.category),
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
}

private extension MainViewModel {
    static func makeLocationText(country: String?, category: String?) -> String {
        [country, category]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
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
            let lowercasedThumbnail = thumbnail.lowercased()

            return [".jpg", ".jpeg", ".png", ".webp"].contains { imageExtension in
                lowercasedThumbnail.hasSuffix(imageExtension)
            }
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

    static func makeNetworkErrorMessage(from error: NetworkError) -> String {
        switch error {
        case .missingAuthenticationToken:
            return "로그인이 필요합니다."
        case .statusCode(_, let message, _):
            return message ?? "NEW 액티비티를 불러오지 못했습니다."
        case .requestFailed:
            return "네트워크 연결을 확인해 주세요."
        case .decodingFailed:
            return "액티비티 정보를 읽는 중 문제가 발생했습니다."
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
