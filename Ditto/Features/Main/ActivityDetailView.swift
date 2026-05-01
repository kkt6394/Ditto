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
    // zoom 진입 시 zoom이 hero에 도달한 뒤 본문이 fade-in되도록 하는 opacity 상태.
    @State private var bodyOpacity: Double = 1
    // 결제 시트는 ActivityDetailView가 직접 보유한다. 결제 완료 후에도 Detail 화면은 그대로 유지된다.
    @State private var isPresentingPayment = false

    private let authManager: any AuthManaging
    private let onStartChat: (String, String) -> Void

    init(
        activityId: String,
        authManager: any AuthManaging,
        onStartChat: @escaping (String, String) -> Void = { _, _ in }
    ) {
        _viewModel = State(initialValue: ActivityDetailViewModel(activityId: activityId, authManager: authManager))
        self.authManager = authManager
        self.onStartChat = onStartChat
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
            // 좋아요 탭에서 zoom과 함께 진입한 경우, 본문은 zoom이 끝난 뒤 fade-in 한다.
            // 다른 진입 경로는 즉시 보인다.
            if likesZoomActive {
                bodyOpacity = 0
                try? await Task.sleep(for: .milliseconds(380))
                withAnimation(.easeOut(duration: 0.32)) {
                    bodyOpacity = 1
                }
            } else {
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
        switch error {
        case let error as NetworkError:
            switch error {
            case .missingAuthenticationToken:
                return "로그인이 필요합니다."
            case .statusCode(_, let message, _):
                return message ?? fallback
            case .requestFailed:
                return "네트워크 연결을 확인해 주세요."
            default:
                return fallback
            }
        case AppConfigurationError.missingValue, AppConfigurationError.invalidURL:
            return "API 설정값을 확인해 주세요."
        default:
            return fallback
        }
    }
}

private struct ActivityDetailRemoteImage: View {
    let request: URLRequest?
    let fallbackImageName: String

    @State private var remoteImage: UIImage?
    @State private var didFailLoadingRemoteImage = false

    var body: some View {
        fittedImage
            .frame(maxWidth: .infinity)
            .frame(height: 360)
            .clipped()
    }

    @ViewBuilder
    private var fittedImage: some View {
        if let remoteImage {
            Image(uiImage: remoteImage)
                .resizable()
                .scaledToFill()
        } else if let request, !didFailLoadingRemoteImage {
            Rectangle()
                .fill(MainScreenPalette.border)
                .overlay {
                    ProgressView()
                        .tint(MainScreenPalette.primaryBlue)
                }
                .task(id: request.url?.absoluteString) {
                    await loadRemoteImage(from: request)
                }
        } else {
            Image(fallbackImageName)
                .resizable()
                .scaledToFill()
        }
    }

    private func loadRemoteImage(from request: URLRequest) async {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let image = UIImage(data: data) else {
                didFailLoadingRemoteImage = true
                return
            }

            remoteImage = image
        } catch {
            didFailLoadingRemoteImage = true
        }
    }
}

private struct ActivityPricePanel: View {
    let originalPrice: String
    let finalPrice: String
    let discountRate: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(originalPrice)
                .font(MainFont.paperlogyBlack(size: 14))
                .foregroundStyle(MainScreenPalette.textMuted)
                .strikethrough()

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    priceTexts
                }

                VStack(alignment: .leading, spacing: 4) {
                    priceTexts
                }
            }
            .font(MainFont.paperlogyBlack(size: 22))
            .foregroundStyle(MainScreenPalette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(MainScreenPalette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MainScreenPalette.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var priceTexts: some View {
        Text("판매가")
        Text(finalPrice)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        if let discountRate {
            Text(discountRate)
                .foregroundStyle(MainScreenPalette.primaryBlue)
                .lineLimit(1)
        }
    }
}

private struct ActivityLimitPanel: View {
    let activity: ActivityResponseDTO

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ActivityLimitItem(title: "최소 키", value: "\(Int(activity.restrictions.minHeight))cm")
            ActivityLimitItem(title: "최소 나이", value: "\(Int(activity.restrictions.minAge))세")
            ActivityLimitItem(title: "최대 인원", value: "\(Int(activity.restrictions.maxParticipants))명")
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(MainScreenPalette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MainScreenPalette.border, lineWidth: 1)
        )
    }
}

private struct ActivityLimitItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(MainScreenTypography.timestamp)
                .foregroundStyle(MainScreenPalette.textSecondary)

            Text(value)
                .font(MainFont.pretendard(.bold, size: 14))
                .foregroundStyle(MainScreenPalette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ActivityDetailBadgeGroup: View {
    let activity: ActivityResponseDTO

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                badges
            }

            VStack(alignment: .leading, spacing: 8) {
                badges
            }
        }
    }

    @ViewBuilder
    private var badges: some View {
        PostInfoBadge(text: activity.country ?? "위치 정보 없음", systemName: "location.fill")
        PostInfoBadge(text: activity.category ?? "액티비티", systemName: "tag.fill")
    }
}

private struct ActivitySchedulePanel: View {
    let schedule: [ActivityScheduleItemDTO]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("액티비티 커리큘럼")
                .font(MainScreenTypography.sectionTitle)
                .foregroundStyle(MainScreenPalette.textPrimary)

            ForEach(Array(schedule.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.duration ?? "진행 시간")
                        .font(MainFont.pretendard(.bold, size: 14))
                        .foregroundStyle(MainScreenPalette.textPrimary)

                    Text(item.description ?? "상세 커리큘럼이 없습니다.")
                        .font(MainScreenTypography.body)
                        .foregroundStyle(MainScreenPalette.textSecondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MainScreenPalette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}

private struct PostInfoBadge: View {
    let text: String
    let systemName: String

    var body: some View {
        Label(text, systemImage: systemName)
            .font(MainScreenTypography.chip)
            .foregroundStyle(MainScreenPalette.primaryBlue)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(
                MainScreenPalette.surface,
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(MainScreenPalette.borderBlue, lineWidth: 1)
            )
    }
}

private struct ActivityDetailStateView: View {
    let title: String
    let systemName: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(MainScreenPalette.primaryBlue)

            Text(title)
                .font(MainScreenTypography.sectionTitle)
                .foregroundStyle(MainScreenPalette.textPrimary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }
}
