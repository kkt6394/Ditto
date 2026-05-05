//
//  ReviewComposeViewModel.swift
//  Ditto
//
//  Created by Codex on 5/4/26.
//

import Foundation
import Observation

// 리뷰 작성/수정/삭제 + 사진 업로드 ViewModel.
// 사진은 업로드 API로 path를 먼저 받아두고, create/update body의 reviewImageUrls에 포함시킨다.
@MainActor
@Observable
final class ReviewComposeViewModel {
    let activityId: String

    var content: String = ""
    var rating: Int = 5
    private(set) var uploadedImagePaths: [String] = []
    private(set) var isUploadingImage = false
    private(set) var isSubmitting = false
    private(set) var isDeleting = false
    var message: String?

    private let networkManagerProvider: @MainActor () throws -> any NetworkManaging

    convenience init(activityId: String, authManager: any AuthManaging) {
        self.init(activityId: activityId) {
            let configuration = try AppConfiguration()
            return NetworkManager(configuration: configuration, authManager: authManager)
        }
    }

    init(
        activityId: String,
        networkManagerProvider: @escaping @MainActor () throws -> any NetworkManaging
    ) {
        self.activityId = activityId
        self.networkManagerProvider = networkManagerProvider
    }

    func prefill(from review: ReviewResponseDTO) {
        content = review.content
        rating = review.rating
        uploadedImagePaths = review.reviewImageUrls
    }

    @discardableResult
    func uploadImage(filename: String, mimeType: String, data: Data) async -> Bool {
        isUploadingImage = true
        message = nil
        defer { isUploadingImage = false }

        do {
            let file = try MultipartFile(filename: filename, mimeType: mimeType, data: data)
                .validated(against: .reviewFiles)
            let networkManager = try networkManagerProvider()
            let response: ReviewImageResponseDTO = try await networkManager.request(
                ReviewRouter.uploadFiles(
                    activityId: activityId,
                    request: ReviewFileUploadRequestDTO(files: [file])
                )
            )
            uploadedImagePaths.append(contentsOf: response.reviewImageUrls)
            return true
        } catch {
            message = NetworkErrorMapper.userMessage(from: error, fallback: "리뷰 사진 업로드에 실패했습니다.")
            return false
        }
    }

    func removeUploadedImage(at index: Int) {
        guard uploadedImagePaths.indices.contains(index) else { return }
        uploadedImagePaths.remove(at: index)
    }

    @discardableResult
    func submit(orderCode: String) async -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            message = "리뷰 내용을 입력해 주세요."
            return false
        }
        guard (1...5).contains(rating) else {
            message = "별점은 1~5점 사이여야 합니다."
            return false
        }

        isSubmitting = true
        message = nil
        defer { isSubmitting = false }

        do {
            let networkManager = try networkManagerProvider()
            let request = ReviewCreateRequestDTO(
                content: trimmed,
                rating: rating,
                reviewImageUrls: uploadedImagePaths.isEmpty ? nil : uploadedImagePaths,
                orderCode: orderCode
            )
            let _: ReviewResponseDTO = try await networkManager.request(
                ReviewRouter.create(activityId: activityId, request: request)
            )
            return true
        } catch {
            message = NetworkErrorMapper.userMessage(from: error, fallback: "리뷰 작성에 실패했습니다.")
            return false
        }
    }

    @discardableResult
    func update(reviewId: String) async -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        isSubmitting = true
        message = nil
        defer { isSubmitting = false }

        do {
            let networkManager = try networkManagerProvider()
            let request = ReviewUpdateRequestDTO(
                content: trimmed.isEmpty ? nil : trimmed,
                rating: rating,
                reviewImageUrls: uploadedImagePaths
            )
            let _: ReviewResponseDTO = try await networkManager.request(
                ReviewRouter.update(activityId: activityId, reviewId: reviewId, request: request)
            )
            return true
        } catch {
            message = NetworkErrorMapper.userMessage(from: error, fallback: "리뷰를 수정하지 못했습니다.")
            return false
        }
    }

    @discardableResult
    func delete(reviewId: String) async -> Bool {
        isDeleting = true
        message = nil
        defer { isDeleting = false }

        do {
            let networkManager = try networkManagerProvider()
            try await networkManager.send(
                ReviewRouter.delete(activityId: activityId, reviewId: reviewId)
            )
            return true
        } catch {
            message = NetworkErrorMapper.userMessage(from: error, fallback: "리뷰를 삭제하지 못했습니다.")
            return false
        }
    }
}
