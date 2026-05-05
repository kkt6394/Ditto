//
//  ActivityDetailViewModel.swift
//  Ditto
//
//  Created by Codex on 4/28/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class ActivityDetailViewModel {
    let activityId: String
    private(set) var activity: ActivityResponseDTO?
    private(set) var heroImageRequest: URLRequest?
    private(set) var isLoading = false
    private(set) var message: String?
    private(set) var reviews: [ReviewResponseDTO] = []
    private(set) var isLoadingReviews = false
    private(set) var reviewsMessage: String?
    private(set) var chatStartMessage: String?
    private(set) var currentUserId: String?

    private let authManager: any AuthManaging

    init(activityId: String, authManager: any AuthManaging) {
        self.activityId = activityId
        self.authManager = authManager
    }

    func loadDetail() async {
        isLoading = true
        message = nil
        defer {
            isLoading = false
        }

        do {
            let configuration = try AppConfiguration()
            let networkManager = NetworkManager(configuration: configuration, authManager: authManager)
            let response: ActivityResponseDTO = try await networkManager.request(
                ActivityRouter.detail(activityId: activityId)
            )
            activity = response
            heroImageRequest = makeImageRequest(
                from: response.thumbnails.first(where: ActivityFormatting.isImagePath),
                configuration: configuration
            )
        } catch {
            message = Self.makeErrorMessage(from: error)
        }
    }

    // 리뷰 목록과 내 user_id를 병렬로 불러온다. 내 리뷰일 때 채팅 버튼을 숨기기 위함.
    func loadReviews() async {
        isLoadingReviews = true
        reviewsMessage = nil
        defer {
            isLoadingReviews = false
        }

        do {
            let networkManager = try makeNetworkManager()

            let response: ReviewListResponseDTO = try await networkManager.request(
                ReviewRouter.list(ReviewListQuery(activityId: activityId, next: nil, limit: nil, orderBy: nil))
            )
            reviews = response.data

            if let myInfo: MyInfoResponseDTO = try? await networkManager.request(UserRouter.myProfile) {
                currentUserId = myInfo.userId
            }
        } catch {
            reviewsMessage = Self.makeReviewsErrorMessage(from: error)
        }
    }

    @discardableResult
    func deleteReview(reviewId: String) async -> Bool {
        do {
            let networkManager = try makeNetworkManager()
            try await networkManager.send(
                ReviewRouter.delete(activityId: activityId, reviewId: reviewId)
            )
            await loadReviews()
            return true
        } catch {
            reviewsMessage = Self.makeReviewsErrorMessage(from: error)
            return false
        }
    }

    func createChatRoom(opponentId: String) async -> ChatRoomResponseDTO? {
        chatStartMessage = nil

        do {
            let networkManager = try makeNetworkManager()
            let request = ChatRoomCreateRequestDTO(opponentId: opponentId)
            return try await networkManager.request(ChatRouter.createRoom(request))
        } catch {
            do {
                let networkManager = try makeNetworkManager()
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

    func reviewImageRequest(for path: String) -> URLRequest? {
        guard let configuration = try? AppConfiguration() else {
            return nil
        }

        return makeImageRequest(from: path, configuration: configuration)
    }

    private func makeNetworkManager() throws -> any NetworkManaging {
        let configuration = try AppConfiguration()
        return NetworkManager(configuration: configuration, authManager: authManager)
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

    func priceText(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        let numberText = formatter.string(from: NSNumber(value: price)) ?? "\(Int(price))"
        return "\(numberText)원"
    }

    func discountRateText(originalPrice: Double, finalPrice: Double) -> String? {
        guard originalPrice > finalPrice, originalPrice > 0 else {
            return nil
        }

        let discount = ((originalPrice - finalPrice) / originalPrice * 100).rounded()
        return "\(Int(discount))%"
    }

    private func makeImageRequest(from path: String?, configuration: AppConfiguration) -> URLRequest? {
        guard let path, !path.isEmpty, let url = makeURL(from: path, baseURL: configuration.baseURL) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue(configuration.apiKey, forHTTPHeaderField: "SeSACKey")

        if let accessToken = authManager.tokens?.accessToken {
            request.setValue(accessToken, forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func makeURL(from path: String, baseURL: URL) -> URL? {
        if let url = URL(string: path), url.scheme != nil {
            return url
        }

        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var imagePath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if imagePath.hasPrefix("data/") {
            imagePath = "v1/" + imagePath
        }

        components.path = "/" + [basePath, imagePath]
            .filter { !$0.isEmpty }
            .joined(separator: "/")

        return components.url
    }

    private static func makeErrorMessage(from error: Error) -> String {
        Self.makeMessage(from: error, fallback: "액티비티 정보를 불러오지 못했습니다.")
    }

    private static func makeReviewsErrorMessage(from error: Error) -> String {
        Self.makeMessage(from: error, fallback: "리뷰를 불러오지 못했습니다.")
    }

    private static func makeChatStartErrorMessage(from error: Error) -> String {
        Self.makeMessage(from: error, fallback: "채팅방을 만들지 못했습니다.")
    }

    private static func makeMessage(from error: Error, fallback: String) -> String {
        NetworkErrorMapper.userMessage(from: error, fallback: fallback)
    }
}
