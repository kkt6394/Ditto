//
//  PostDetailViewModel.swift
//  Ditto
//
//  Created by Codex on 5/4/26.
//

import Foundation
import Observation

// 포스트 상세 화면용 ViewModel.
// API 호출과 도메인 상태만 담당하고, 화면 디자인은 별도로 도입될 예정이다.
@MainActor
@Observable
final class PostDetailViewModel {
    let postId: String

    private(set) var post: PostResponseDTO?
    private(set) var isLoading = false
    private(set) var isMutating = false
    private(set) var currentUserId: String?
    var message: String?

    private let networkManagerProvider: @MainActor () throws -> any NetworkManaging
    private let authManager: any AuthManaging

    convenience init(postId: String, authManager: any AuthManaging) {
        self.init(
            postId: postId,
            networkManagerProvider: {
                let configuration = try AppConfiguration()
                return NetworkManager(configuration: configuration, authManager: authManager)
            },
            authManager: authManager
        )
    }

    init(
        postId: String,
        networkManagerProvider: @escaping @MainActor () throws -> any NetworkManaging,
        authManager: any AuthManaging
    ) {
        self.postId = postId
        self.networkManagerProvider = networkManagerProvider
        self.authManager = authManager
    }

    func load() async {
        isLoading = true
        message = nil
        defer { isLoading = false }

        do {
            let networkManager = try networkManagerProvider()
            let response: PostResponseDTO = try await networkManager.request(PostRouter.detail(postId: postId))
            post = response

            // 본인 댓글 판별을 위해 내 user_id를 함께 캐시한다 (실패는 무시).
            if currentUserId == nil {
                if let myInfo: MyInfoResponseDTO = try? await networkManager.request(UserRouter.myProfile) {
                    currentUserId = myInfo.userId
                }
            }
        } catch {
            message = NetworkErrorMapper.userMessage(from: error, fallback: "포스트를 불러오지 못했습니다.")
        }
    }

    // 포스트의 첨부 파일/프로필 이미지 등을 인증 헤더가 포함된 URLRequest로 변환한다.
    func imageRequest(for path: String?) -> URLRequest? {
        guard let path, !path.isEmpty,
              let configuration = try? AppConfiguration() else {
            return nil
        }

        return ActivityFormatting.makeImageRequest(
            from: path,
            configuration: configuration,
            accessToken: authManager.tokens?.accessToken
        )
    }

    @discardableResult
    func toggleLike() async -> Bool {
        guard let current = post else { return false }
        return await mutate(fallback: "좋아요를 변경하지 못했습니다.") { networkManager in
            let request = PostLikeRequestDTO(likeStatus: !current.isLike)
            let response: PostLikeResponseDTO = try await networkManager.request(
                PostRouter.like(postId: self.postId, request: request)
            )
            // 서버 응답 기준으로 isLike와 likeCount를 갱신한다.
            self.post = current.applying(isLike: response.likeStatus)
        }
    }

    @discardableResult
    func update(_ request: PostUpdateRequestDTO) async -> Bool {
        await mutate(fallback: "포스트를 수정하지 못했습니다.") { networkManager in
            let response: PostResponseDTO = try await networkManager.request(
                PostRouter.update(postId: self.postId, request: request)
            )
            self.post = response
        }
    }

    @discardableResult
    func delete() async -> Bool {
        await mutate(fallback: "포스트를 삭제하지 못했습니다.") { networkManager in
            try await networkManager.send(PostRouter.delete(postId: self.postId))
            self.post = nil
        }
    }

    private func mutate(
        fallback: String,
        _ work: @MainActor (any NetworkManaging) async throws -> Void
    ) async -> Bool {
        isMutating = true
        message = nil
        defer { isMutating = false }

        do {
            let networkManager = try networkManagerProvider()
            try await work(networkManager)
            return true
        } catch {
            message = NetworkErrorMapper.userMessage(from: error, fallback: fallback)
            return false
        }
    }
}

private extension PostResponseDTO {
    // 좋아요 토글 응답에는 likeCount가 없으므로 클라이언트가 ±1로 보정한다.
    func applying(isLike: Bool) -> PostResponseDTO {
        let delta: Double = isLike == self.isLike ? 0 : (isLike ? 1 : -1)
        return PostResponseDTO(
            postId: postId,
            country: country,
            category: category,
            title: title,
            content: content,
            activity: activity,
            geolocation: geolocation,
            creator: creator,
            files: files,
            isLike: isLike,
            likeCount: max(0, likeCount + delta),
            comments: comments,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
