//
//  MainPostComponents.swift
//  Ditto
//
//  Created by 김기태 on 4/25/26.
//

import SwiftUI
import UIKit

struct ActivityPostsSection: View {
    let posts: [MainActivityPost]
    let isLoading: Bool
    let message: String?
    let mediaAction: (MainPostMedia) -> Void
    let detailAction: (MainActivityPost) -> Void
    let chatAction: (MainActivityPost) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(MainScreenPalette.border)

            HStack {
                Text("액티비티 포스트")
                    .font(MainScreenTypography.sectionTitle)
                    .foregroundStyle(MainScreenPalette.textPrimary)

                Spacer()

                HStack(spacing: 4) {
                    Text("최신순")
                        .font(MainScreenTypography.action)
                        .foregroundStyle(MainScreenPalette.primaryBlue)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(MainScreenPalette.primaryBlue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            if isLoading && posts.isEmpty {
                ActivityPostStateCard(
                    title: "액티비티 포스트를 불러오는 중입니다.",
                    systemName: "arrow.clockwise"
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            } else if posts.isEmpty {
                ActivityPostStateCard(
                    title: message ?? "액티비티 포스트가 없습니다.",
                    subtitle: "다른 나라나 카테고리를 선택해 보세요.",
                    systemName: "text.bubble"
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            } else {
                ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                    ActivityPostCard(
                        post: post,
                        mediaAction: mediaAction,
                        detailAction: detailAction,
                        chatAction: chatAction
                    )

                    if index != posts.indices.last {
                        Divider()
                            .padding(.horizontal, 20)
                            .overlay(MainScreenPalette.border)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(MainScreenPalette.surface)
    }
}

private struct ActivityPostStateCard: View {
    let title: String
    var subtitle: String?
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

            if let subtitle {
                Text(subtitle)
                    .font(MainScreenTypography.body)
                    .foregroundStyle(MainScreenPalette.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MainScreenPalette.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(MainScreenPalette.border, lineWidth: 1)
        )
    }
}

private struct ActivityPostCard: View {
    let post: MainActivityPost
    let mediaAction: (MainPostMedia) -> Void
    let detailAction: (MainActivityPost) -> Void
    let chatAction: (MainActivityPost) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                chatAction(post)
            } label: {
                HStack(spacing: 8) {
                    ActivityPostRemoteImage(
                        request: post.profileImageRequest,
                        fallbackImageName: post.profileImageName,
                        width: 32,
                        height: 32,
                        cornerRadius: 16
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(post.author)
                            .font(MainScreenTypography.author)
                            .foregroundStyle(MainScreenPalette.textPrimary)

                        Text(post.timeText)
                            .font(MainScreenTypography.timestamp)
                            .foregroundStyle(MainScreenPalette.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 22)
            .zIndex(1)

            ActivityPostImageCollage(post: post, mediaAction: mediaAction)
                .padding(.horizontal, 20)
                .zIndex(0)

            Button {
                detailAction(post)
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text(post.title)
                        .font(MainScreenTypography.postTitle)
                        .foregroundStyle(MainScreenPalette.textPrimary)

                    Text(post.body)
                        .font(MainScreenTypography.postBody)
                        .foregroundStyle(MainScreenPalette.textSecondary)
                        .lineSpacing(4)

                    HStack(spacing: 10) {
                        PostInfoChip(text: post.location, showsIcon: true)
                        PostInfoChip(text: post.category, showsIcon: false)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 22)
        }
        .padding(.vertical, 20)
    }
}

private struct ActivityPostImageCollage: View {
    let post: MainActivityPost
    let mediaAction: (MainPostMedia) -> Void

    var body: some View {
        HStack(spacing: 4) {
            if let mainMedia = post.media[safe: 0] {
                ActivityPostMediaButton(
                    media: mainMedia,
                    width: 226,
                    height: 160,
                    cornerRadius: 18,
                    showsLikeBadge: true,
                    isLiked: post.isLiked,
                    action: mediaAction
                )
            }

            VStack(spacing: 4) {
                if let topMedia = post.media[safe: 1] {
                    ActivityPostMediaButton(
                        media: topMedia,
                        width: 120,
                        height: 78,
                        cornerRadius: 14,
                        showsLikeBadge: false,
                        isLiked: post.isLiked,
                        action: mediaAction
                    )
                }

                if let bottomMedia = post.media[safe: 2] {
                    ActivityPostMediaButton(
                        media: bottomMedia,
                        width: 120,
                        height: 78,
                        cornerRadius: 14,
                        showsLikeBadge: false,
                        isLiked: post.isLiked,
                        action: mediaAction
                    )
                }
            }
        }
    }
}

private struct ActivityPostMediaButton: View {
    let media: MainPostMedia
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat
    let showsLikeBadge: Bool
    let isLiked: Bool
    let action: (MainPostMedia) -> Void

    var body: some View {
        Button {
            action(media)
        } label: {
            ZStack {
                ActivityPostRemoteImage(
                    request: media.kind == .image ? media.request : nil,
                    fallbackImageName: media.fallbackImageName,
                    width: width,
                    height: height,
                    cornerRadius: cornerRadius
                )

                if showsLikeBadge {
                    VStack {
                        HStack {
                            LikeBadge(isLiked: isLiked)
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(10)
                }

                if media.kind == .video {
                    PlayBadge()
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct ActivityPostRemoteImage: View {
    let request: URLRequest?
    let fallbackImageName: String
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

    @Environment(\.imageLoader) private var imageLoader
    @State private var remoteImage: UIImage?
    @State private var didFailLoadingRemoteImage = false

    var body: some View {
        fittedImage
            .frame(width: width, height: height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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
            // 표시 크기에 맞게 다운샘플링 — 원본 디코딩 메모리 절감 (보통 10배 이상)
            let pointSize = CGSize(width: width, height: height)
            // 환경에 인증 로더가 주입되어 있으면 토큰 만료(419) 자동 갱신 흐름을 탄다.
            let image: UIImage
            if let imageLoader {
                image = try await imageLoader.loadImage(request, pointSize: pointSize)
            } else {
                image = try await RemoteImageLoader.load(request: request, pointSize: pointSize)
            }
            remoteImage = image
        } catch {
            didFailLoadingRemoteImage = true
        }
    }
}

private struct LikeBadge: View {
    let isLiked: Bool

    var body: some View {
        Image(systemName: isLiked ? "heart.fill" : "heart")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isLiked ? Color(red: 1.0, green: 0.38, blue: 0.52) : .white)
            .frame(width: 24, height: 24)
            .background(Color.black.opacity(0.16), in: Circle())
    }
}

private struct PlayBadge: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.74))
                .frame(width: 32, height: 32)

            Image(systemName: "play.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.black.opacity(0.55))
                .offset(x: 1)
        }
    }
}

private struct PostInfoChip: View {
    let text: String
    let showsIcon: Bool

    var body: some View {
        HStack(spacing: 4) {
            if showsIcon {
                Image(systemName: "location.fill")
                    .font(.system(size: 10, weight: .semibold))
            }

            Text(text)
                .lineLimit(1)
        }
        .font(MainScreenTypography.chip)
        .foregroundStyle(MainScreenPalette.primaryBlue)
        .padding(.horizontal, 8)
        .frame(height: 20)
        .background(
            MainScreenPalette.background,
            in: RoundedRectangle(cornerRadius: 4, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(MainScreenPalette.borderBlue, lineWidth: 1)
        )
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct MainBottomTabBar: View {
    @Environment(KeepStore.self) private var keepStore
    let items: [MainTabItem]
    let selectedID: String
    let selectionAction: (MainTabItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ForEach(items) { item in
                    Button {
                        selectionAction(item)
                    } label: {
                        let isSelected = item.id == selectedID
                        let isLikesTab = item.id == MainTab.likes.rawValue

                        VStack(spacing: 6) {
                            Image(systemName: item.systemName)
                                .font(.system(size: 20, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(
                                    isSelected
                                        ? MainScreenPalette.textPrimary
                                        : MainScreenPalette.textMuted
                                )
                                .symbolEffect(
                                    .bounce,
                                    value: isLikesTab ? keepStore.keptActivityIDs.count : 0
                                )
                                .anchorPreference(
                                    key: ActivityHeartAnchorKey.self,
                                    value: .center
                                ) { anchor in
                                    isLikesTab
                                        ? [ActivityHeartAnchorKey.tabSentinelID: anchor]
                                        : [:]
                                }

                            Text(item.title)
                                .font(MainScreenTypography.tab)
                                .foregroundStyle(
                                    isSelected
                                        ? MainScreenPalette.textPrimary
                                        : MainScreenPalette.textMuted
                                )
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
        }
        .padding(.bottom, 0)
        .frame(maxWidth: .infinity)
        .background(
            MainScreenPalette.surface
                .ignoresSafeArea(edges: .bottom)
        )
        .background(alignment: .top) {
            Divider()
                .overlay(MainScreenPalette.borderBlue.opacity(0.35))
        }
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: 20,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 20,
                style: .continuous
            )
                .fill(MainScreenPalette.surface)
                .shadow(color: MainScreenPalette.shadow, radius: 6, y: -1)
        )
    }
}
