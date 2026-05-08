//
//  FeedPostCard.swift
//  Ditto
//
//  Created by Codex on 5/8/26.
//

import SwiftUI
import UIKit

// 피드 탭의 액티비티 포스트 카드. 헤더(작성자) + 메시지 버튼 + ActivityPostImageCollage 재사용 + 본문 + CTA + 소셜 액션.
// 메시지 버튼 = 채팅 액션, 콜라주 탭 = 풀스크린 미디어 뷰어, 본문 탭 = 포스트 상세.
struct FeedPostCard: View {
    let post: MainActivityPost
    let mediaAction: (MainPostMedia) -> Void
    let detailAction: (MainActivityPost) -> Void
    let chatAction: (MainActivityPost) -> Void
    let likeAction: (MainActivityPost) -> Void
    let activityAction: (MainActivityPost) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            authorHeader

            ActivityPostImageCollage(post: post, mediaAction: mediaAction)
                .padding(.horizontal, 20)

            bodyAndChips

            // 본문 아래 활동 미리보기 — 포스트가 가리키는 액티비티 카드 한 줄 요약
            if post.activityId != nil {
                FeedActivityPreviewCard(post: post)
                    .padding(.horizontal, 22)
                    .onTapGesture {
                        activityAction(post)
                    }
            }

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
            // 좋아요 — 아이콘 + 카운트. 탭 시 좋아요 토글, 활성 시 symbolEffect.bounce
            HStack(spacing: 4) {
                Image(systemName: post.isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(post.isLiked ? MainScreenPalette.primaryBlue : MainScreenPalette.textPrimary)
                    .symbolEffect(.bounce, value: post.isLiked)

                Text("\(post.likeCount)")
                    .font(MainScreenTypography.action)
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: post.likeCount)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                likeAction(post)
            }

            // 댓글 — 아이콘 + 카운트. PostSummaryResponseDTO에 comment_count 부재로 카운트는 placeholder(0).
            HStack(spacing: 4) {
                Image(systemName: "bubble.right")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(MainScreenPalette.textPrimary)

                Text("\(post.commentCount)")
                    .font(MainScreenTypography.action)
                    .foregroundStyle(MainScreenPalette.textPrimary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                detailAction(post)
            }

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

// 피드 카드 본문 아래에 노출되는 활동 한 줄 미리보기.
// 좌측 작은 썸네일 + 우측 카테고리·제목·가격 + 끝 chevron으로 활동 진입을 유도한다.
private struct FeedActivityPreviewCard: View {
    let post: MainActivityPost

    var body: some View {
        HStack(spacing: 12) {
            FeedActivityThumbnail(post: post)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                if let category = post.activityCategory {
                    Text(category)
                        .font(MainScreenTypography.activityMetaCompact)
                        .foregroundStyle(MainScreenPalette.primaryBlue)
                }

                Text(post.activityTitle ?? post.category)
                    .font(MainScreenTypography.postTitle)
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .lineLimit(1)

                if let price = post.activityFinalPrice {
                    Text(price)
                        .font(MainScreenTypography.activityPriceCompact)
                        .foregroundStyle(MainScreenPalette.textPrimary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MainScreenPalette.textSecondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(MainScreenPalette.primaryBlueSoft.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MainScreenPalette.borderBlue, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct FeedActivityThumbnail: View {
    let post: MainActivityPost
    @Environment(\.imageLoader) private var imageLoader
    @State private var remoteImage: UIImage?
    @State private var didFail = false

    var body: some View {
        ZStack {
            if let remoteImage {
                Image(uiImage: remoteImage)
                    .resizable()
                    .scaledToFill()
            } else if let request = post.activityImageRequest, !didFail {
                Color(MainScreenPalette.border)
                    .task(id: request.url?.absoluteString) {
                        await load(request: request)
                    }
            } else {
                Color(MainScreenPalette.border)
                    .overlay {
                        Image(systemName: "figure.outdoor.cycle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(MainScreenPalette.textSecondary)
                    }
            }
        }
        .clipped()
    }

    private func load(request: URLRequest) async {
        do {
            let image: UIImage
            if let imageLoader {
                image = try await imageLoader.loadImage(request, pointSize: CGSize(width: 56, height: 56))
            } else {
                image = try await RemoteImageLoader.load(request: request, pointSize: CGSize(width: 56, height: 56))
            }
            remoteImage = image
        } catch {
            didFail = true
        }
    }
}
