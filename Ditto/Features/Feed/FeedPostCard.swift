//
//  FeedPostCard.swift
//  Ditto
//
//  Created by Codex on 5/8/26.
//

import SwiftUI

// 피드 탭의 액티비티 포스트 카드. 헤더(작성자) + 메시지 버튼 + ActivityPostImageCollage 재사용 + 본문 + CTA + 소셜 액션.
// 메시지 버튼 = 채팅 액션, 콜라주 탭 = 풀스크린 미디어 뷰어, 본문 탭 = 포스트 상세.
struct FeedPostCard: View {
    let post: MainActivityPost
    let mediaAction: (MainPostMedia) -> Void
    let detailAction: (MainActivityPost) -> Void
    let chatAction: (MainActivityPost) -> Void
    let likeAction: (MainActivityPost) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            authorHeader

            ActivityPostImageCollage(post: post, mediaAction: mediaAction)
                .padding(.horizontal, 20)

            bodyAndChips

            socialActions
        }
        .padding(.vertical, 20)
    }

    private var authorHeader: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(MainScreenPalette.border)
                .frame(width: 32, height: 32)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(MainScreenPalette.textSecondary)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(post.author)
                    .font(MainScreenTypography.author)
                    .foregroundStyle(MainScreenPalette.textPrimary)

                Text(post.timeText)
                    .font(MainScreenTypography.timestamp)
                    .foregroundStyle(MainScreenPalette.textSecondary)
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "bubble.left.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("메시지")
                    .font(MainScreenTypography.action)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(
                Capsule(style: .continuous)
                    .fill(MainScreenPalette.primaryBlue)
            )
            .contentShape(Capsule(style: .continuous))
            .onTapGesture {
                chatAction(post)
            }
        }
        .padding(.horizontal, 22)
    }

    private var bodyAndChips: some View {
        Button {
            detailAction(post)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text(post.title)
                    .font(MainScreenTypography.postTitle)
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .multilineTextAlignment(.leading)

                Text(post.body)
                    .font(MainScreenTypography.postBody)
                    .foregroundStyle(MainScreenPalette.textSecondary)
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 10) {
                    chip(text: post.location, systemName: "mappin.and.ellipse")
                    chip(text: post.category, systemName: nil)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 22)
    }

    private var socialActions: some View {
        HStack(spacing: 18) {
            // 좋아요 — 탭 시 좋아요 토글, 활성 시 symbolEffect.bounce로 인터랙션 강조
            Image(systemName: post.isLiked ? "heart.fill" : "heart")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(post.isLiked ? MainScreenPalette.primaryBlue : MainScreenPalette.textPrimary)
                .symbolEffect(.bounce, value: post.isLiked)
                .contentShape(Rectangle())
                .onTapGesture {
                    likeAction(post)
                }

            // 댓글 — 탭 시 포스트 상세로 진입(댓글 영역까지 스크롤은 후속)
            Image(systemName: "bubble.right")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(MainScreenPalette.textPrimary)
                .contentShape(Rectangle())
                .onTapGesture {
                    detailAction(post)
                }

            // 북마크 — DTO에 플래그 부재로 1차 placeholder. 회색 비활성.
            Image(systemName: "bookmark")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(MainScreenPalette.textMuted)

            Spacer()
        }
        .padding(.horizontal, 22)
    }

    private func chip(text: String, systemName: String?) -> some View {
        HStack(spacing: 4) {
            if let systemName {
                Image(systemName: systemName)
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(text)
                .font(MainScreenTypography.chip)
        }
        .padding(.horizontal, 10)
        .frame(height: 26)
        .foregroundStyle(MainScreenPalette.primaryBlue)
        .background(
            Capsule(style: .continuous)
                .fill(MainScreenPalette.primaryBlueSoft)
        )
    }

}
