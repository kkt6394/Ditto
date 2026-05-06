//
//  VideoListViewModel.swift
//  Ditto
//
//  Created by Codex on 5/4/26.
//

import Foundation
import Observation

// 비디오 목록 + 좋아요 토글 + 스트림 URL 발급 ViewModel.
@MainActor
@Observable
final class VideoListViewModel {
    private(set) var videos: [VideoResponseDTO] = []
    private(set) var nextCursor: String?
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var togglingLikeIDs: Set<String> = []
    var message: String?

    private let networkManagerProvider: @MainActor () throws -> any NetworkManaging
    // 썸네일 이미지나 스트림/자막 URL을 절대 URL로 변환할 때 사용한다.
    private let configurationProvider: @MainActor () throws -> AppConfiguration
    private let authManager: any AuthManaging

    convenience init(authManager: any AuthManaging) {
        self.init(
            authManager: authManager,
            networkManagerProvider: {
                let configuration = try AppConfiguration()
                return NetworkManager(configuration: configuration, authManager: authManager)
            },
            configurationProvider: {
                try AppConfiguration()
            }
        )
    }

    init(
        authManager: any AuthManaging,
        networkManagerProvider: @escaping @MainActor () throws -> any NetworkManaging,
        configurationProvider: @escaping @MainActor () throws -> AppConfiguration
    ) {
        self.authManager = authManager
        self.networkManagerProvider = networkManagerProvider
        self.configurationProvider = configurationProvider
    }

    func loadFirstPage() async {
        isLoading = true
        message = nil
        defer { isLoading = false }

        do {
            let networkManager = try networkManagerProvider()
            let response: VideoListResponseDTO = try await networkManager.request(
                VideoRouter.list(VideoListQuery(next: nil, limit: nil))
            )
            videos = response.data
            nextCursor = response.nextCursor
        } catch {
            message = NetworkErrorMapper.userMessage(from: error, fallback: "비디오 목록을 불러오지 못했습니다.")
        }
    }

    func loadMore() async {
        guard let cursor = nextCursor, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let networkManager = try networkManagerProvider()
            let response: VideoListResponseDTO = try await networkManager.request(
                VideoRouter.list(VideoListQuery(next: cursor, limit: nil))
            )
            videos.append(contentsOf: response.data)
            nextCursor = response.nextCursor
        } catch {
            message = NetworkErrorMapper.userMessage(from: error, fallback: "비디오 목록을 더 불러오지 못했습니다.")
        }
    }

    // 스트림 URL 발급. 응답값에는 토큰이 쿼리에 포함된 상대경로가 들어 있어 절대 URL로 변환한다.
    func fetchStreamURL(videoId: String) async throws -> StreamUrlResponseDTO {
        let networkManager = try networkManagerProvider()
        let response: StreamUrlResponseDTO = try await networkManager.request(
            VideoRouter.stream(videoId: videoId)
        )
        return response
    }

    // 썸네일 등 인증 헤더가 필요한 경로용 URLRequest 생성.
    func makeAuthorizedImageRequest(for path: String) -> URLRequest? {
        guard let url = absoluteURL(for: path, prefixV1ForData: true) else { return nil }
        guard let configuration = try? configurationProvider() else { return nil }

        var request = URLRequest(url: url)
        request.setValue(configuration.apiKey, forHTTPHeaderField: "SeSACKey")
        if let token = authManager.tokens?.accessToken {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        return request
    }

    // 명세 본문에는 stream 경로가 v1 prefix 없이 적혀 있지만, 실제 서버는 /v1 + SeSACKey 헤더를
    // 요구한다. AVPlayer가 후속으로 받을 .m4s/init.mp4/자막 vtt도 같은 규약을 따른다.
    func makeStreamURL(from path: String) -> URL? {
        let normalized = path.hasPrefix("/") ? "/v1" + path : "v1/" + path
        return absoluteURL(for: normalized, prefixV1ForData: false)
    }

    // AVURLAsset에 주입할 HTTP 헤더. 스트림/자막 요청에 SeSACKey가 자동으로 따라가게 한다.
    func streamHTTPHeaders() -> [String: String] {
        guard let configuration = try? configurationProvider() else { return [:] }
        return ["SeSACKey": configuration.apiKey]
    }

    // 자막(WebVTT)도 stream과 마찬가지로 /v1 접두사가 필요하지만,
    // stream과 달리 Authorization 헤더까지 함께 요구한다. SeSACKey만 보내면 403을 받는다.
    func makeAuthorizedSubtitleRequest(for path: String) -> URLRequest? {
        guard let url = makeStreamURL(from: path) else { return nil }
        guard let configuration = try? configurationProvider() else { return nil }

        var request = URLRequest(url: url)
        request.setValue(configuration.apiKey, forHTTPHeaderField: "SeSACKey")
        if let token = authManager.tokens?.accessToken {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        return request
    }

    // 외부 .vtt 파일을 받아 텍스트로 돌려준다. 실패 시 throw 하지만, 호출부에서는 자막 부재로 간주한다.
    func loadSubtitleText(for path: String) async throws -> String {
        guard let request = makeAuthorizedSubtitleRequest(for: path) else {
            throw URLError(.badURL)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }
        return text
    }

    // 상대경로를 절대 URL로 변환한다.
    // - prefixV1ForData: true이면 `/data/...` 경로 앞에 v1을 붙인다(이미지·썸네일 규약).
    private func absoluteURL(for path: String, prefixV1ForData: Bool) -> URL? {
        guard let configuration = try? configurationProvider() else { return nil }

        if let url = URL(string: path), url.scheme != nil {
            return url
        }

        guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var relativePath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let queryStart = relativePath.firstIndex(of: "?")
        let pathOnly = queryStart.map { String(relativePath[..<$0]) } ?? relativePath
        let queryOnly = queryStart.map { String(relativePath[relativePath.index(after: $0)...]) }

        var normalizedPath = pathOnly
        if prefixV1ForData, normalizedPath.hasPrefix("data/") {
            normalizedPath = "v1/" + normalizedPath
        }

        components.path = "/" + [basePath, normalizedPath]
            .filter { !$0.isEmpty }
            .joined(separator: "/")

        if let query = queryOnly {
            components.percentEncodedQuery = query
        }

        relativePath = normalizedPath
        return components.url
    }

    @discardableResult
    func toggleLike(for videoId: String) async -> Bool {
        guard let index = videos.firstIndex(where: { $0.videoId == videoId }) else { return false }
        guard !togglingLikeIDs.contains(videoId) else { return false }

        togglingLikeIDs.insert(videoId)
        defer { togglingLikeIDs.remove(videoId) }

        let current = videos[index]
        let nextLike = !current.isLiked

        do {
            let networkManager = try networkManagerProvider()
            let response: VideoLikeResponseDTO = try await networkManager.request(
                VideoRouter.like(videoId: videoId, request: VideoLikeRequestDTO(likeStatus: nextLike))
            )
            videos[index] = current.applying(isLiked: response.likeStatus)
            return true
        } catch {
            message = NetworkErrorMapper.userMessage(from: error, fallback: "좋아요를 변경하지 못했습니다.")
            return false
        }
    }
}

private extension VideoResponseDTO {
    // 좋아요 토글 응답에 likeCount가 없어 클라이언트에서 ±1로 보정한다.
    func applying(isLiked: Bool) -> VideoResponseDTO {
        let delta: Int = isLiked == self.isLiked ? 0 : (isLiked ? 1 : -1)
        return VideoResponseDTO(
            videoId: videoId,
            fileName: fileName,
            title: title,
            description: description,
            duration: duration,
            thumbnailUrl: thumbnailUrl,
            availableQualities: availableQualities,
            viewCount: viewCount,
            likeCount: max(0, likeCount + delta),
            isLiked: isLiked,
            createdAt: createdAt
        )
    }
}
