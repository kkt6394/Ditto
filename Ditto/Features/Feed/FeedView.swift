//
//  FeedView.swift
//  Ditto
//
//  Created by Codex on 5/8/26.
//

import SwiftUI

// 피드 탭. 정렬 메뉴 + LazyVStack(FeedPostCard) 구조.
// 검색·영상·로고는 MainView가 모든 탭에 공통으로 띄우는 상단 바에서 처리한다.
struct FeedView: View {
    @Bindable var viewModel: MainViewModel
    let mediaAction: (MainPostMedia) -> Void
    let detailAction: (MainActivityPost) -> Void
    let chatAction: (MainActivityPost) -> Void
    let activityAction: (MainActivityPost) -> Void

    @State private var orderBy: PostOrderBy = .createdAt

    private let topAnchorID = "feed-top"

    var body: some View {
        VStack(spacing: 0) {
            titleSortRow

            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        // 정렬 변경 시 맨 위로 이동하기 위한 sentinel anchor.
                        Color.clear
                            .frame(height: 0)
                            .id(topAnchorID)

                        if viewModel.isLoadingActivityPosts && viewModel.activityPosts.isEmpty {
                            FeedPlaceholderCard()
                                .padding(.horizontal, 20)
                                .padding(.top, 12)
                        } else if viewModel.activityPosts.isEmpty {
                            FeedEmptyCard(text: viewModel.activityPostsMessage ?? "표시할 액티비티 포스트가 없습니다.")
                                .padding(.horizontal, 20)
                                .padding(.top, 12)
                        } else {
                            ForEach(Array(viewModel.activityPosts.enumerated()), id: \.element.id) { index, post in
                                FeedPostCard(
                                    post: post,
                                    mediaAction: mediaAction,
                                    detailAction: detailAction,
                                    chatAction: chatAction,
                                    likeAction: { tappedPost in
                                        Task { await viewModel.togglePostLike(postId: tappedPost.id) }
                                    },
                                    activityAction: activityAction
                                )
                                .onAppear {
                                    // 카드가 화면에 들어오면 댓글 갯수를 prefetch (한 번만).
                                    Task { await viewModel.prefetchCommentCount(forPostId: post.id) }

                                    // 마지막 카드가 보이기 시작하면 다음 페이지를 prefetch.
                                    // ViewModel이 cursor 없거나 동시 호출이면 내부에서 무시한다.
                                    if index == viewModel.activityPosts.count - 1 {
                                        Task {
                                            await viewModel.loadMoreActivityPosts(
                                                country: nil,
                                                category: nil,
                                                orderBy: orderBy
                                            )
                                        }
                                    }
                                }
                                Divider()
                                    .padding(.horizontal, 20)
                                    .overlay(MainScreenPalette.border)
                            }

                            if viewModel.isLoadingMoreActivityPosts {
                                ProgressView()
                                    .padding(.vertical, 16)
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
                .task(id: orderBy) {
                    // 정렬 토글 시 스크롤을 즉시 맨 위로 보내고 첫 페이지부터 다시 로드한다.
                    // 새 데이터가 들어오기 전에 스크롤을 reset해 깜빡임 없이 위에서부터 채워지도록 한다.
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(topAnchorID, anchor: .top)
                    }
                    await viewModel.loadActivityPosts(
                        country: nil,
                        category: nil,
                        orderBy: orderBy
                    )
                }
            }
        }
        .background(MainScreenPalette.background.ignoresSafeArea())
    }

    // 공통 TopBar 아래 한 줄 — 좌측 Feed 타이틀, 우측 정렬 메뉴.
    private var titleSortRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Feed")
                .font(.system(size: 26, design: .serif))
                .italic()
                .foregroundStyle(MainScreenPalette.textPrimary)

            Spacer()

            Menu {
                Button("최신순") {
                    orderBy = .createdAt
                }
                Button("인기순") {
                    orderBy = .likes
                }
            } label: {
                HStack(spacing: 4) {
                    Text(orderBy == .createdAt ? "최신순" : "인기순")
                        .font(MainScreenTypography.action)
                        .foregroundStyle(MainScreenPalette.primaryBlue)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(MainScreenPalette.primaryBlue)
                }
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
}

private struct FeedPlaceholderCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(MainScreenPalette.primaryBlue)

            Text("액티비티 포스트를 불러오는 중입니다.")
                .font(MainScreenTypography.sectionTitle)
                .foregroundStyle(MainScreenPalette.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MainScreenPalette.surface)
        )
    }
}

private struct FeedEmptyCard: View {
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.bubble")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(MainScreenPalette.primaryBlue)

            Text(text)
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MainScreenPalette.surface)
        )
    }
}
