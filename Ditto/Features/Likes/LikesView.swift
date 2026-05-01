//
//  LikesView.swift
//  Ditto
//
//  Created by Codex on 5/1/26.
//

import SwiftUI

struct LikesView: View {
    @Environment(KeepStore.self) private var keepStore
    let activityDetailAction: (String) -> Void

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .background(MainScreenPalette.background.ignoresSafeArea())
        .task {
            await keepStore.loadLikedActivities()
        }
    }

    private var header: some View {
        HStack {
            Text("좋아요")
                .font(MainScreenTypography.brand)
                .foregroundStyle(MainScreenPalette.primaryBlue)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .frame(height: 44)
    }

    @ViewBuilder
    private var content: some View {
        if keepStore.isLoadingLikedActivities && keepStore.likedActivities.isEmpty {
            loadingState
        } else if let message = keepStore.likedActivitiesMessage,
                  keepStore.likedActivities.isEmpty {
            errorState(message)
        } else if keepStore.likedActivities.isEmpty {
            emptyState
        } else {
            gridList
        }
    }

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("좋아요한 액티비티를 불러오는 중입니다.")
                .font(MainScreenTypography.bodyCompact)
                .foregroundStyle(MainScreenPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart")
                .font(.system(size: 56, weight: .medium))
                .foregroundStyle(MainScreenPalette.textMuted)
            Text("아직 좋아요한 액티비티가 없습니다.")
                .font(MainFont.pretendard(.bold, size: 16))
                .foregroundStyle(MainScreenPalette.textPrimary)
            Text("마음에 드는 액티비티를 좋아요해 보세요.")
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(MainScreenPalette.textMuted)
            Text(message)
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                Task { await keepStore.loadLikedActivities() }
            } label: {
                Text("다시 시도")
                    .font(MainFont.pretendard(.bold, size: 14))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(MainScreenPalette.primaryBlue, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var gridList: some View {
        ScrollView(showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(keepStore.likedActivities) { activity in
                    Button {
                        activityDetailAction(activity.id)
                    } label: {
                        LikedActivityCard(activity: activity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .animation(.spring(response: 0.4, dampingFraction: 0.78), value: keepStore.likedActivities)
        }
        .refreshable {
            await keepStore.loadLikedActivities()
        }
    }
}

struct LikedActivityCard: View {
    let activity: LikedActivity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                ZStack(alignment: .topTrailing) {
                    SearchRemoteImage(
                        request: activity.imageRequest,
                        fallbackImageName: "FigmaMainNewActivity1",
                        width: proxy.size.width,
                        height: proxy.size.width,
                        cornerRadius: 14
                    )

                    ActivityKeepHeart(activityId: activity.id, size: 28)
                        .padding(8)
                }
            }
            .aspectRatio(1, contentMode: .fit)

            VStack(alignment: .leading, spacing: 4) {
                Text(activity.title)
                    .font(MainFont.pretendard(.bold, size: 14))
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .lineLimit(1)

                Text(activity.location)
                    .font(MainScreenTypography.activityMetaCompact)
                    .foregroundStyle(MainScreenPalette.textSecondary)
                    .lineLimit(1)

                Text(activity.priceText)
                    .font(MainFont.pretendard(.bold, size: 14))
                    .foregroundStyle(MainScreenPalette.primaryBlue)
            }
            .padding(.horizontal, 4)
        }
        .transition(.asymmetric(
            insertion: .scale(scale: 0.92).combined(with: .opacity),
            removal: .opacity.combined(with: .scale(scale: 0.94))
        ))
    }
}
