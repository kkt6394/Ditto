//
//  VideoListViewModel.swift
//  Ditto
//
//  Created by Codex on 5/4/26.
//

import Foundation
import Observation

// 비디오 목록 + 좋아요 토글 ViewModel.
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

    convenience init(authManager: any AuthManaging) {
        self.init {
            let configuration = try AppConfiguration()
            return NetworkManager(configuration: configuration, authManager: authManager)
        }
    }

    init(networkManagerProvider: @escaping @MainActor () throws -> any NetworkManaging) {
        self.networkManagerProvider = networkManagerProvider
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
            nextCursor = response.nextCursor.isEmpty ? nil : response.nextCursor
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
            nextCursor = response.nextCursor.isEmpty ? nil : response.nextCursor
        } catch {
            message = NetworkErrorMapper.userMessage(from: error, fallback: "비디오 목록을 더 불러오지 못했습니다.")
        }
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
