//
//  ProfileTabView.swift
//  Ditto
//
//  Created by Codex on 5/1/26.
//

import SwiftUI

struct ProfileTabView: View {
    // 좋아요한 액티비티 데이터는 좋아요 탭과 동일한 KeepStore를 단일 소스로 사용한다.
    @Environment(KeepStore.self) private var keepStore
    // 탭이 활성화될 때마다 내 포스트를 다시 fetch해 새 글이 즉시 반영되게 한다.
    let isActive: Bool
    let signOutMessage: String?
    let signOutAction: () -> Void
    let orderListAction: () -> Void
    let composeActivityAction: () -> Void

    @State private var viewModel: ProfileViewModel
    @State private var isPresentingEditor = false
    @State private var isPresentingWithdrawConfirm = false

    init(
        authManager: any AuthManaging,
        isActive: Bool,
        signOutMessage: String?,
        signOutAction: @escaping () -> Void,
        orderListAction: @escaping () -> Void,
        composeActivityAction: @escaping () -> Void
    ) {
        self.isActive = isActive
        self.signOutMessage = signOutMessage
        self.signOutAction = signOutAction
        self.orderListAction = orderListAction
        self.composeActivityAction = composeActivityAction
        _viewModel = State(initialValue: ProfileViewModel(authManager: authManager))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    profileCard
                    statsRow
                    actionButtons
                    if let message = signOutMessage {
                        ProfileMessageBanner(message: message)
                    }
                    if let actionMessage = viewModel.actionMessage {
                        ProfileMessageBanner(message: actionMessage)
                    }
                    myPostsSection
                    likedActivitiesSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 80)
            }
            .refreshable {
                async let profileTask: Void = viewModel.loadAll()
                async let likesTask: Void = keepStore.loadLikedActivities()
                _ = await (profileTask, likesTask)
            }
        }
        .background(MainScreenPalette.background.ignoresSafeArea())
        .task {
            if viewModel.profile == nil {
                await viewModel.loadAll()
            }
            // 좋아요 탭에 한 번도 들어간 적이 없으면 KeepStore가 비어 있을 수 있어 여기서 한 번 시드한다.
            if keepStore.likedActivities.isEmpty {
                await keepStore.loadLikedActivities()
            }
        }
        .onChange(of: isActive) { _, newValue in
            // 탭 진입 시 새로 작성한 포스트와 좋아요 변동분이 즉시 반영되게 갱신한다.
            guard newValue else { return }
            Task {
                await viewModel.loadMyPosts()
                await keepStore.loadLikedActivities()
            }
        }
        .sheet(isPresented: $isPresentingEditor) {
            ProfileEditView(viewModel: viewModel)
        }
        .alert("정말 회원탈퇴 하시겠습니까?", isPresented: $isPresentingWithdrawConfirm) {
            Button("취소", role: .cancel) { }
            Button("탈퇴", role: .destructive) {
                Task {
                    let success = await viewModel.withdraw()
                    if success {
                        // 서버 처리는 끝났지만 화면 라우팅은 ContentView가 isAuthenticated 변화로 자동 처리한다.
                        viewModel.actionMessage = nil
                    }
                }
            }
        } message: {
            Text("탈퇴 후에는 복구할 수 없습니다.")
        }
    }

    private var header: some View {
        HStack {
            Text("프로필")
                .font(MainScreenTypography.brand)
                .foregroundStyle(MainScreenPalette.primaryBlue)
            Spacer()
            Button {
                isPresentingEditor = true
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("프로필 편집")
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .frame(height: 56)
    }

    @ViewBuilder
    private var profileCard: some View {
        if viewModel.isLoadingProfile && viewModel.profile == nil {
            ProfileCardSkeleton()
        } else if let profile = viewModel.profile {
            ProfileHeaderCard(
                profile: profile,
                imageRequest: viewModel.profileImageRequest
            )
        } else if let message = viewModel.profileMessage {
            ProfileErrorCard(message: message) {
                Task { await viewModel.loadProfile() }
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            ProfileStatTile(title: "내 포스트", value: "\(viewModel.myPosts.count)")
            ProfileStatTile(title: "좋아요", value: "\(keepStore.likedActivities.count)")
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            Button {
                isPresentingEditor = true
            } label: {
                ProfileActionRow(
                    title: "프로필 편집",
                    systemImage: "pencil",
                    style: .primary
                )
            }
            .buttonStyle(.plain)

            Button(action: orderListAction) {
                ProfileActionRow(
                    title: "주문 내역",
                    systemImage: "doc.text",
                    style: .secondary
                )
            }
            .buttonStyle(.plain)

            Button(action: composeActivityAction) {
                ProfileActionRow(
                    title: "액티비티 등록",
                    systemImage: "plus.square",
                    style: .secondary
                )
            }
            .buttonStyle(.plain)

            Button(action: signOutAction) {
                ProfileActionRow(
                    title: "로그아웃",
                    systemImage: "rectangle.portrait.and.arrow.right",
                    style: .secondary
                )
            }
            .buttonStyle(.plain)

            Button {
                isPresentingWithdrawConfirm = true
            } label: {
                ProfileActionRow(
                    title: viewModel.isWithdrawing ? "탈퇴 처리 중..." : "회원탈퇴",
                    systemImage: "person.crop.circle.badge.xmark",
                    style: .destructive
                )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isWithdrawing)
        }
    }

    @ViewBuilder
    private var myPostsSection: some View {
        ProfileSectionHeader(title: "내 포스트")

        if viewModel.isLoadingMyPosts && viewModel.myPosts.isEmpty {
            ProfileSectionLoading()
        } else if viewModel.myPosts.isEmpty {
            ProfileSectionEmpty(message: viewModel.myPostsMessage ?? "아직 작성한 포스트가 없습니다.")
        } else {
            ProfilePostHorizontalList(items: viewModel.myPosts)
        }
    }

    @ViewBuilder
    private var likedActivitiesSection: some View {
        ProfileSectionHeader(title: "좋아요한 액티비티")

        if keepStore.isLoadingLikedActivities && keepStore.likedActivities.isEmpty {
            ProfileSectionLoading()
        } else if keepStore.likedActivities.isEmpty {
            ProfileSectionEmpty(
                message: keepStore.likedActivitiesMessage ?? "아직 좋아요한 액티비티가 없습니다."
            )
        } else {
            ProfileLikedActivityHorizontalList(items: keepStore.likedActivities)
        }
    }
}
