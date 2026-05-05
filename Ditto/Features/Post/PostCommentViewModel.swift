//
//  PostCommentViewModel.swift
//  Ditto
//
//  Created by Codex on 5/4/26.
//

import Foundation
import Observation

// 포스트 댓글 작성/수정/삭제용 ViewModel.
// 댓글 목록은 PostDetailViewModel.post.comments에 포함되어 있어 별도로 관리하지 않는다.
@MainActor
@Observable
final class PostCommentViewModel {
    let postId: String

    private(set) var isMutating = false
    var message: String?

    var didMutate: (@MainActor () async -> Void)?

    private let networkManagerProvider: @MainActor () throws -> any NetworkManaging

    convenience init(postId: String, authManager: any AuthManaging) {
        self.init(postId: postId) {
            let configuration = try AppConfiguration()
            return NetworkManager(configuration: configuration, authManager: authManager)
        }
    }

    init(
        postId: String,
        networkManagerProvider: @escaping @MainActor () throws -> any NetworkManaging
    ) {
        self.postId = postId
        self.networkManagerProvider = networkManagerProvider
    }

    @discardableResult
    func create(content: String, parentCommentId: String? = nil) async -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            message = "댓글 내용을 입력해 주세요."
            return false
        }

        return await mutate(fallback: "댓글을 작성하지 못했습니다.") { networkManager in
            let request = CommentRequestDTO(parentCommentId: parentCommentId, content: trimmed)
            let _: CommentResponseDTO = try await networkManager.request(
                PostRouter.createComment(postId: self.postId, request: request)
            )
        }
    }

    @discardableResult
    func update(commentId: String, content: String) async -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            message = "댓글 내용을 입력해 주세요."
            return false
        }

        return await mutate(fallback: "댓글을 수정하지 못했습니다.") { networkManager in
            let request = CommentUpdateRequestDTO(content: trimmed)
            let _: CommentResponseDTO = try await networkManager.request(
                PostRouter.updateComment(postId: self.postId, commentId: commentId, request: request)
            )
        }
    }

    @discardableResult
    func delete(commentId: String) async -> Bool {
        await mutate(fallback: "댓글을 삭제하지 못했습니다.") { networkManager in
            try await networkManager.send(
                PostRouter.deleteComment(postId: self.postId, commentId: commentId)
            )
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
            await didMutate?()
            return true
        } catch {
            message = NetworkErrorMapper.userMessage(from: error, fallback: fallback)
            return false
        }
    }
}
