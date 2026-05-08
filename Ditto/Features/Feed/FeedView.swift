//
//  FeedView.swift
//  Ditto
//
//  Created by Codex on 5/8/26.
//

import SwiftUI

// 피드 탭. 헤더(타이틀 + 검색 버튼) + 정렬 메뉴 + LazyVStack(FeedPostCard) 구조.
// 별도 ViewModel을 두지 않고 MainViewModel.activityPosts/loadActivityPosts를 그대로 사용한다.
struct FeedView: View {
    @Bindable var viewModel: MainViewModel
    let searchAction: () -> Void
    let mediaAction: (MainPostMedia) -> Void
    let detailAction: (MainActivityPost) -> Void
    let chatAction: (MainActivityPost) -> Void

    @State private var orderBy: PostOrderBy = .createdAt

    var body: some View {
        VStack(spacing: 0) {
            header

            sortRow

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    if viewModel.isLoadingActivityPosts && viewModel.activityPosts.isEmpty {
                        FeedPlaceholderCard()
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                    } else if viewModel.activityPosts.isEmpty {
                        FeedEmptyCard(text: viewModel.activityPostsMessage ?? "표시할 액티비티 포스트가 없습니다.")
                            .padding(.horizontal, 20)
                            .padding(.top, 12)
                    } else {
                        ForEach(viewModel.activityPosts) { post in
                            FeedPostCard(
                                post: post,
                                mediaAction: mediaAction,
                                detailAction: detailAction,
                                chatAction: chatAction
                            )
                            Divider()
                                .padding(.horizontal, 20)
                                .overlay(MainScreenPalette.border)
                        }
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .background(MainScreenPalette.background.ignoresSafeArea())
        .task(id: orderBy) {
            await viewModel.loadActivityPosts(
                country: nil,
                category: nil,
                orderBy: orderBy
            )
        }
    }

    private var header: some View {
        HStack {
            Text("Feed")
                .font(.system(size: 26, design: .serif))
                .italic()
                .foregroundStyle(MainScreenPalette.textPrimary)

            Spacer()

            Button(action: searchAction) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 56)
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var sortRow: some View {
        HStack {
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
