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
    @Binding var distanceKilometers: Double
    let locationMessage: String?

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

            DistanceSliderCard(
                distanceKilometers: $distanceKilometers,
                locationMessage: locationMessage
            )
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

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
                    ActivityPostCard(post: post)

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

private struct DistanceSliderCard: View {
    @Binding var distanceKilometers: Double
    let locationMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text("Distance")
                    .font(MainScreenTypography.distance)
                    .foregroundStyle(MainScreenPalette.textMuted)

                Text("\(Int(distanceKilometers.rounded()))KM")
                    .font(MainScreenTypography.distance)
                    .foregroundStyle(MainScreenPalette.primaryBlue)
            }

            Slider(value: $distanceKilometers, in: 1...50, step: 1)
                .tint(MainScreenPalette.primaryBlue)

            if let locationMessage {
                Text(locationMessage)
                    .font(MainScreenTypography.timestamp)
                    .foregroundStyle(MainScreenPalette.textSecondary)
                    .lineLimit(2)
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
                ActivityPostRemoteImage(
                    request: post.mainImageRequest,
                    fallbackImageName: post.mainImageName,
                    width: 226,
                    height: 160,
                    cornerRadius: 18
                )

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
                ActivityPostRemoteImage(
                    request: post.subImageTopRequest,
                    fallbackImageName: post.subImageTopName,
                    width: 120,
                    height: 78,
                    cornerRadius: 14
                )

                ActivityPostRemoteImage(
                    request: post.subImageBottomRequest,
                    fallbackImageName: post.subImageBottomName,
                    width: 120,
                    height: 78,
                    cornerRadius: 14
                )
            }
        }
    }
}

private struct ActivityPostRemoteImage: View {
    let request: URLRequest?
    let fallbackImageName: String
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

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

                        VStack(spacing: 6) {
                            Image(systemName: item.systemName)
                                .font(.system(size: 20, weight: isSelected ? .bold : .medium))
                                .foregroundStyle(
                                    isSelected
                                        ? MainScreenPalette.textPrimary
                                        : MainScreenPalette.textMuted
                                )

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

struct ProfileTabView: View {
    let signOutMessage: String?
    let signOutAction: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            MainTopBar()
                .padding(.horizontal, 20)
                .padding(.top, 12)

            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("프로필")
                        .font(MainFont.pretendard(.bold, size: 24))
                        .foregroundStyle(MainScreenPalette.textPrimary)

                    Text("로그인 테스트를 위해 현재 인증 정보를 초기화할 수 있습니다.")
                        .font(MainScreenTypography.body)
                        .foregroundStyle(MainScreenPalette.textSecondary)
                }

                if let signOutMessage {
                    Label(signOutMessage, systemImage: "exclamationmark.circle.fill")
                        .font(MainFont.pretendard(.semibold, size: 13))
                        .foregroundStyle(Color(red: 0.72, green: 0.18, blue: 0.14))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            Color(red: 0.72, green: 0.18, blue: 0.14).opacity(0.10),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                }

                Button(role: .destructive, action: signOutAction) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16, weight: .semibold))

                        Text("로그아웃")
                            .font(MainFont.pretendard(.bold, size: 16))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        Color(red: 0.72, green: 0.18, blue: 0.14),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 26)
        }
    }
}
