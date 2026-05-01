//
//  ProfileTabView.swift
//  Ditto
//
//  Created by Codex on 5/1/26.
//

import SwiftUI

struct ProfileTabView: View {
    let signOutMessage: String?
    let signOutAction: () -> Void

    @State private var viewModel: ProfileViewModel
    @State private var isPresentingEditor = false
    @State private var isPresentingWithdrawConfirm = false

    init(
        authManager: any AuthManaging,
        signOutMessage: String?,
        signOutAction: @escaping () -> Void
    ) {
        self.signOutMessage = signOutMessage
        self.signOutAction = signOutAction
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
                    likedPostsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 80)
            }
            .refreshable {
                await viewModel.loadAll()
            }
        }
        .background(MainScreenPalette.background.ignoresSafeArea())
        .task {
            if viewModel.profile == nil {
                await viewModel.loadAll()
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
            ProfileStatTile(title: "좋아요", value: "\(viewModel.likedPosts.count)")
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
    private var likedPostsSection: some View {
        ProfileSectionHeader(title: "좋아요한 포스트")

        if viewModel.isLoadingLikedPosts && viewModel.likedPosts.isEmpty {
            ProfileSectionLoading()
        } else if viewModel.likedPosts.isEmpty {
            ProfileSectionEmpty(message: viewModel.likedPostsMessage ?? "아직 좋아요한 포스트가 없습니다.")
        } else {
            ProfilePostHorizontalList(items: viewModel.likedPosts)
        }
    }
}
