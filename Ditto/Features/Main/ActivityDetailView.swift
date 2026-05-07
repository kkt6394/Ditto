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
    @State private var editingReview: ReviewResponseDTO?
    @State private var deletingReview: ReviewResponseDTO?

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
        .sheet(item: $editingReview) { review in
            ReviewComposeView(
                activityId: viewModel.activityId,
                mode: .edit(reviewId: review.reviewId, prefill: review),
                authManager: authManager
            ) {
                Task { await viewModel.loadReviews() }
            }
        }
        .alert("리뷰를 삭제할까요?", isPresented: deletePresentationBinding) {
            Button("취소", role: .cancel) { deletingReview = nil }
            Button("삭제", role: .destructive) {
                if let target = deletingReview {
                    Task { await viewModel.deleteReview(reviewId: target.reviewId) }
                }
                deletingReview = nil
            }
        } message: {
            Text("삭제한 리뷰는 복구할 수 없습니다.")
        }
    }

    private var deletePresentationBinding: Binding<Bool> {
        Binding(
            get: { deletingReview != nil },
            set: { newValue in
                if !newValue { deletingReview = nil }
            }
        )
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
            sentimentSummary: viewModel.reviewSentimentSummary,
            aiSummary: viewModel.reviewAISummary,
            isAnalyzing: viewModel.isAnalyzingReviews,
            imageRequestProvider: { path in
                viewModel.reviewImageRequest(for: path)
            },
            chatAction: { review in
                startChat(with: review)
            },
            editAction: { review in
                editingReview = review
            },
            deleteAction: { review in
                deletingReview = review
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
