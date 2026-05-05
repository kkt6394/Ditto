//
//  ActivityDetailView.swift
//  Ditto
//
//  Created by Codex on 4/28/26.
//

import Observation
import SwiftUI
import UIKit

struct ActivityDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(KeepStore.self) private var keepStore
    @Environment(\.likesHeroNamespace) private var likesHeroNamespace
    @Environment(\.likesZoomActive) private var likesZoomActive

    @State private var viewModel: ActivityDetailViewModel
    @State private var pendingChatOpponentIDs: Set<String> = []
    // zoom 진입 시 zoom이 hero에 도달할 때까지 detail의 hero 이미지를 가리고,
    // 도달 직후 hero를 노출, 그 뒤 본문을 fade-in 한다.
    @State private var heroOpacity: Double = 0
    @State private var bodyOpacity: Double = 0
    // 결제 시트는 ActivityDetailView가 직접 보유한다. 결제 완료 후에도 Detail 화면은 그대로 유지된다.
    @State private var isPresentingPayment = false

    private let authManager: any AuthManaging
    private let onStartChat: (String, String) -> Void
    private let onStartEdit: (String) -> Void

    init(
        activityId: String,
        authManager: any AuthManaging,
        onStartChat: @escaping (String, String) -> Void = { _, _ in },
        onStartEdit: @escaping (String) -> Void = { _ in }
    ) {
        _viewModel = State(initialValue: ActivityDetailViewModel(activityId: activityId, authManager: authManager))
        self.authManager = authManager
        self.onStartChat = onStartChat
        self.onStartEdit = onStartEdit
    }

    // 본인이 작성한 액티비티인 경우에만 우상단 "수정" 버튼을 노출한다.
    private var canEditCurrentActivity: Bool {
        guard let myId = viewModel.currentUserId,
              let creatorId = viewModel.activity?.creator.userId,
              !myId.isEmpty else { return false }
        return myId == creatorId
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                navigationBar

                if viewModel.isLoading && viewModel.activity == nil {
                    ActivityDetailStateView(title: "액티비티 상세 정보를 불러오는 중입니다.", systemName: "arrow.clockwise")
                        .frame(maxHeight: .infinity)
                } else if let activity = viewModel.activity {
                    detailContent(activity)
                } else {
                    ActivityDetailStateView(
                        title: viewModel.message ?? "액티비티 정보를 확인할 수 없습니다.",
                        systemName: "exclamationmark.circle"
                    )
                    .frame(maxHeight: .infinity)
                }
            }

            if let activity = viewModel.activity {
                reservationCallToAction(for: activity)
            }
        }
        .background(MainScreenPalette.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: viewModel.activityId) {
            await viewModel.loadDetail()
        }
        .task(id: viewModel.activityId) {
            await viewModel.loadReviews()
        }
        .onChange(of: viewModel.activity?.isKeep) { _, isKept in
            guard let isKept else { return }
            keepStore.registerInitialKeepStatus(
                activityId: viewModel.activityId,
                isKept: isKept
            )
        }
        .sheet(isPresented: $isPresentingPayment) {
            if let activity = viewModel.activity {
                PaymentView(
                    activity: activity,
                    authManager: authManager
                )
            }
        }
    }

    private func reservationCallToAction(for activity: ActivityResponseDTO) -> some View {
        // 예약 항목이 비어 있거나 모든 시간이 매진(isReserved)인 경우 모두 "예약 불가"로 통일한다.
        let isAvailable = hasAvailableReservation(activity)

        return VStack(spacing: 0) {
            Button {
                isPresentingPayment = true
            } label: {
                Text(isAvailable ? "예약하기" : "예약 불가")
                    .font(MainFont.pretendard(.bold, size: 16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        isAvailable ? MainScreenPalette.primaryBlue : MainScreenPalette.textMuted,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .disabled(!isAvailable)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
        .background(
            MainScreenPalette.background
                .opacity(0.95)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func hasAvailableReservation(_ activity: ActivityResponseDTO) -> Bool {
        activity.reservationList.contains { item in
            item.times.contains { slot in
                slot.time != nil && !(slot.isReserved ?? false)
            }
        }
    }

    private var navigationBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("액티비티")
                .font(MainScreenTypography.brand)
                .foregroundStyle(MainScreenPalette.primaryBlue)

            Spacer()

            if canEditCurrentActivity {
                Button {
                    onStartEdit(viewModel.activityId)
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(MainScreenPalette.textPrimary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("액티비티 수정")
            }

            ActivityKeepHeart(activityId: viewModel.activityId, size: 36)
                .padding(.trailing, 8)
        }
        .padding(.horizontal, 4)
        .frame(height: 44)
        .background(MainScreenPalette.background)
    }

    private func detailContent(_ activity: ActivityResponseDTO) -> some View {
        GeometryReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    ActivityDetailRemoteImage(
                        request: viewModel.heroImageRequest,
                        fallbackImageName: "FigmaMainNewActivity2"
                    )
                    .opacity(heroOpacity)
                    .anchorPreference(
                        key: LikesZoomAnchorKey.self,
                        value: .bounds
                    ) { anchor in
                        [viewModel.activityId: LikesZoomAnchorPair(source: nil, destination: anchor)]
                    }

                    bodyBelowHero(activity)
                        .opacity(bodyOpacity)
                }
                .frame(width: proxy.size.width, alignment: .leading)
                .padding(.bottom, SearchLayout.tabBarContentPadding)
            }
        }
        .task {
            // 좋아요 탭에서 zoom과 함께 진입한 경우:
            //  - zoom이 hero에 도달하기 전(~420ms)까지 detail의 hero/본문을 모두 숨김
            //  - 도달 직후 hero를 즉시 노출(zoom overlay와 같은 위치/이미지라 인계가 자연스러움)
            //  - hero가 자리 잡은 뒤 본문을 부드럽게 fade-in
            // 다른 진입 경로(홈/검색)는 즉시 노출한다.
            if likesZoomActive {
                try? await Task.sleep(for: .milliseconds(420))
                heroOpacity = 1
                try? await Task.sleep(for: .milliseconds(60))
                withAnimation(.easeOut(duration: 0.32)) {
                    bodyOpacity = 1
                }
            } else {
                heroOpacity = 1
                bodyOpacity = 1
            }
        }
    }

    @ViewBuilder
    private func bodyBelowHero(_ activity: ActivityResponseDTO) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 14) {
                Text(activity.title ?? "제목 없는 액티비티")
                    .font(MainFont.paperlogyBlack(size: 26))
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(activity.description ?? "상세 설명이 없습니다.")
                    .font(MainScreenTypography.postBody)
                    .foregroundStyle(MainScreenPalette.textSecondary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                ActivityDetailBadgeGroup(activity: activity)
            }
            .padding(.horizontal, 20)

            ActivityPricePanel(
                originalPrice: viewModel.priceText(activity.price.original),
                finalPrice: viewModel.priceText(activity.price.final),
                discountRate: viewModel.discountRateText(
                    originalPrice: activity.price.original,
                    finalPrice: activity.price.final
                )
            )
            .padding(.horizontal, 20)

            ActivityLimitPanel(activity: activity)
                .padding(.horizontal, 20)

            if let schedule = activity.schedule, !schedule.isEmpty {
                ActivitySchedulePanel(schedule: schedule)
                    .padding(.horizontal, 20)
            }

            reviewSection
                .padding(.horizontal, 20)
        }
    }

    private var reviewSection: some View {
        ReviewSection(
            reviews: viewModel.reviews,
            isLoading: viewModel.isLoadingReviews,
            message: viewModel.reviewsMessage,
            currentUserId: viewModel.currentUserId,
            chatStartMessage: viewModel.chatStartMessage,
            imageRequestProvider: { path in
                viewModel.reviewImageRequest(for: path)
            },
            chatAction: { review in
                startChat(with: review)
            }
        )
    }

    private func startChat(with review: ReviewResponseDTO) {
        let opponentId = review.creator.userId
        let opponentNick = review.creator.nick

        guard pendingChatOpponentIDs.insert(opponentId).inserted else {
            return
        }

        Task { @MainActor in
            defer {
                pendingChatOpponentIDs.remove(opponentId)
            }

            guard let room = await viewModel.createChatRoom(opponentId: opponentId) else {
                return
            }

            onStartChat(room.roomId, opponentNick)
        }
    }
}

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
                from: response.thumbnails.first(where: Self.isImagePath),
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

    private static func isImagePath(_ path: String) -> Bool {
        let lowercasedPath = path.lowercased()

        return [".jpg", ".jpeg", ".png", ".webp"].contains { imageExtension in
            lowercasedPath.hasSuffix(imageExtension)
        }
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
