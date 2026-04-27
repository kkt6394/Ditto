//
//  MainPostComponents.swift
//  Ditto
//
//  Created by 김기태 on 4/25/26.
//

import SwiftUI

struct ActivityPostsSection: View {
    let posts: [MainActivityPost]

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

            DistanceSliderCard()
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            ForEach(Array(posts.enumerated()), id: \.element.id) { index, post in
                ActivityPostCard(post: post)

                if index != posts.indices.last {
                    Divider()
                        .padding(.horizontal, 20)
                        .overlay(MainScreenPalette.border)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(MainScreenPalette.surface)
    }
}

private struct DistanceSliderCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text("Distance")
                    .font(MainScreenTypography.distance)
                    .foregroundStyle(MainScreenPalette.textMuted)

                Text("3KM")
                    .font(MainScreenTypography.distance)
                    .foregroundStyle(MainScreenPalette.primaryBlue)
            }

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(MainScreenPalette.background)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(MainScreenPalette.border, lineWidth: 1)
                    )
                    .frame(height: 36)

                Capsule()
                    .fill(Color(red: 0.918, green: 0.918, blue: 0.918))
                    .frame(height: 10)
                    .padding(.horizontal, 12)

                Capsule()
                    .fill(MainScreenPalette.primaryBlue)
                    .frame(width: 140, height: 10)
                    .padding(.leading, 12)

                Circle()
                    .fill(MainScreenPalette.surface)
                    .overlay(Circle().stroke(MainScreenPalette.primaryBlue, lineWidth: 2))
                    .frame(width: 14, height: 14)
                    .offset(x: 146)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 12)
    }
}

private struct ActivityPostCard: View {
    let post: MainActivityPost

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(post.profileImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(post.author)
                        .font(MainScreenTypography.author)
                        .foregroundStyle(MainScreenPalette.textPrimary)

                    Text(post.timeText)
                        .font(MainScreenTypography.timestamp)
                        .foregroundStyle(MainScreenPalette.textSecondary)
                }
            }
            .padding(.horizontal, 22)

            ActivityPostImageCollage(post: post)
                .padding(.horizontal, 20)

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
            .padding(.horizontal, 22)
        }
        .padding(.vertical, 20)
    }
}

private struct ActivityPostImageCollage: View {
    let post: MainActivityPost

    var body: some View {
        HStack(spacing: 4) {
            ZStack {
                Image(post.mainImageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 226, height: 160)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                VStack {
                    HStack {
                        LikeBadge(isLiked: post.isLiked)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(10)

                PlayBadge()
            }

            VStack(spacing: 4) {
                Image(post.subImageTopName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 78)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Image(post.subImageBottomName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 78)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
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

struct MainBottomTabBar: View {
    let items: [MainTabItem]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                ForEach(items) { item in
                    VStack(spacing: 6) {
                        Image(systemName: item.systemName)
                            .font(.system(size: 20, weight: item.isSelected ? .bold : .medium))
                            .foregroundStyle(
                                item.isSelected
                                    ? MainScreenPalette.textPrimary
                                    : MainScreenPalette.textMuted
                            )

                        Text(item.title)
                            .font(MainScreenTypography.tab)
                            .foregroundStyle(
                                item.isSelected
                                    ? MainScreenPalette.textPrimary
                                    : MainScreenPalette.textMuted
                            )
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 6)
        }
        .padding(.bottom, 2)
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
