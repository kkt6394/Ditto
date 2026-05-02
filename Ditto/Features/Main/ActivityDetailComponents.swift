//
//  ActivityDetailComponents.swift
//  Ditto
//
//  Created by 김기태 on 5/2/26.
//

import SwiftUI
import UIKit

// MARK: - Hero Image

struct ActivityDetailRemoteImage: View {
    let request: URLRequest?
    let fallbackImageName: String

    @State private var remoteImage: UIImage?
    @State private var didFailLoadingRemoteImage = false

    var body: some View {
        fittedImage
            .frame(maxWidth: .infinity)
            .frame(height: 360)
            .clipped()
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
        // 화면 너비 × 360 헤더 — 디바이스 화면 너비 기준으로 다운샘플링
        let pointSize = CGSize(width: UIScreen.main.bounds.width, height: 360)
        do {
            let image = try await RemoteImageLoader.load(
                request: request,
                pointSize: pointSize
            )
            remoteImage = image
        } catch {
            didFailLoadingRemoteImage = true
        }
    }
}

// MARK: - Price / Limits

struct ActivityPricePanel: View {
    let originalPrice: String
    let finalPrice: String
    let discountRate: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(originalPrice)
                .font(MainFont.paperlogyBlack(size: 14))
                .foregroundStyle(MainScreenPalette.textMuted)
                .strikethrough()

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    priceTexts
                }

                VStack(alignment: .leading, spacing: 4) {
                    priceTexts
                }
            }
            .font(MainFont.paperlogyBlack(size: 22))
            .foregroundStyle(MainScreenPalette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(MainScreenPalette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MainScreenPalette.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var priceTexts: some View {
        Text("판매가")
        Text(finalPrice)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        if let discountRate {
            Text(discountRate)
                .foregroundStyle(MainScreenPalette.primaryBlue)
                .lineLimit(1)
        }
    }
}

struct ActivityLimitPanel: View {
    let activity: ActivityResponseDTO

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ActivityLimitItem(title: "최소 키", value: "\(Int(activity.restrictions.minHeight))cm")
            ActivityLimitItem(title: "최소 나이", value: "\(Int(activity.restrictions.minAge))세")
            ActivityLimitItem(title: "최대 인원", value: "\(Int(activity.restrictions.maxParticipants))명")
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(MainScreenPalette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MainScreenPalette.border, lineWidth: 1)
        )
    }
}

struct ActivityLimitItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(MainScreenTypography.timestamp)
                .foregroundStyle(MainScreenPalette.textSecondary)

            Text(value)
                .font(MainFont.pretendard(.bold, size: 14))
                .foregroundStyle(MainScreenPalette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Badges

struct ActivityDetailBadgeGroup: View {
    let activity: ActivityResponseDTO

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                badges
            }

            VStack(alignment: .leading, spacing: 8) {
                badges
            }
        }
    }

    @ViewBuilder
    private var badges: some View {
        PostInfoBadge(text: activity.country ?? "위치 정보 없음", systemName: "location.fill")
        PostInfoBadge(text: activity.category ?? "액티비티", systemName: "tag.fill")
    }
}

struct PostInfoBadge: View {
    let text: String
    let systemName: String

    var body: some View {
        Label(text, systemImage: systemName)
            .font(MainScreenTypography.chip)
            .foregroundStyle(MainScreenPalette.primaryBlue)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(
                MainScreenPalette.surface,
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(MainScreenPalette.borderBlue, lineWidth: 1)
            )
    }
}

// MARK: - Schedule

struct ActivitySchedulePanel: View {
    let schedule: [ActivityScheduleItemDTO]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("액티비티 커리큘럼")
                .font(MainScreenTypography.sectionTitle)
                .foregroundStyle(MainScreenPalette.textPrimary)

            ForEach(Array(schedule.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.duration ?? "진행 시간")
                        .font(MainFont.pretendard(.bold, size: 14))
                        .foregroundStyle(MainScreenPalette.textPrimary)

                    Text(item.description ?? "상세 커리큘럼이 없습니다.")
                        .font(MainScreenTypography.body)
                        .foregroundStyle(MainScreenPalette.textSecondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MainScreenPalette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}

// MARK: - Loading / Empty

struct ActivityDetailStateView: View {
    let title: String
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
        }
        .padding(.horizontal, 24)
    }
}
