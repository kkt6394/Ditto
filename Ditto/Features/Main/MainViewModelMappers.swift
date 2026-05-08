//
//  MainViewModelMappers.swift
//  Ditto
//
//  Created by Codex on 5/8/26.
//

import Foundation

// 정적 mapper와 프라이빗 helper들을 클래스 본체에서 분리한다.
// loadXxx 메서드들은 클래스 본체에 두고, DTO → 도메인 모델 변환과 도시명 비동기 갱신, 정적 헬퍼만 여기 둔다.
extension MainViewModel {
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
            location: ActivityFormatting.makeLocationText(country: response.country),
            title: title,
            price: ActivityFormatting.makePriceText(response.price.final),
            summary: summary,
            imageName: fallback.imageName,
            imageRequest: ActivityFormatting.makeImageRequest(
                from: ActivityFormatting.firstImageThumbnail(from: response.thumbnails),
                configuration: configuration,
                accessToken: accessToken
            ),
            isKeep: response.isKeep
        )
    }

    static func makeErrorMessage(from error: Error) -> String {
        NetworkErrorMapper.userMessage(from: error, fallback: "NEW 액티비티를 불러오지 못했습니다.")
    }

    static func makeBannerErrorMessage(from error: Error) -> String {
        NetworkErrorMapper.userMessage(from: error, fallback: "배너를 불러오지 못했습니다.")
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
            imageRequest: ActivityFormatting.makeImageRequest(
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
            ActivityFormatting.makeImageRequest(from: $0, configuration: configuration, accessToken: accessToken)
        }

        return MainActivityPost(
            id: response.postId,
            activityId: response.activity?.id,
            creatorId: response.creator.userId,
            author: response.creator.nick,
            timeText: makeRelativeTimeText(from: response.createdAt),
            title: response.title,
            body: response.content,
            location: ActivityFormatting.makeLocationText(country: response.country),
            category: response.activity?.title ?? response.category,
            profileImageName: fallback.profileImageName,
            profileImageRequest: ActivityFormatting.makeImageRequest(
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

    static func makeNetworkErrorMessage(from error: NetworkError) -> String {
        NetworkErrorMapper.networkUserMessage(from: error, fallback: "NEW 액티비티를 불러오지 못했습니다.")
    }

    static func makeNetworkErrorMessage(from error: NetworkError, fallbackMessage: String) -> String {
        NetworkErrorMapper.networkUserMessage(from: error, fallback: fallbackMessage)
    }
}

extension MainViewModel {
    static func imagePaths(from paths: [String]) -> [String] {
        paths.filter { ActivityFormatting.isImagePath($0) }
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

            if ActivityFormatting.isImagePath(path) {
                let request = ActivityFormatting.makeImageRequest(
                    from: path,
                    configuration: configuration,
                    accessToken: accessToken
                )
                return .image(id: "\(path)-\(index)", request: request, fallbackImageName: fallbackName)
            }

            if ActivityFormatting.isVideoPath(path) {
                let videoId = ActivityFormatting.videoId(from: path)
                let request = videoId == nil
                    ? ActivityFormatting.makeImageRequest(
                        from: path,
                        configuration: configuration,
                        accessToken: accessToken
                    )
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

        // 사진이 없는 글은 sample fallback(낙하산 사진 3장)을 채우지 않고 빈 배열로 둔다.
        // ActivityPostImageCollage는 post.media[safe: index]로 접근해 빈 배열이면 사진 영역을 그리지 않는다.
        return media
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
