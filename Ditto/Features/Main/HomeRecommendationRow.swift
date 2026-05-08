//
//  HomeRecommendationRow.swift
//  Ditto
//
//  Created by Codex on 5/8/26.
//

import SwiftUI
import UIKit

// 홈 본문 하단에 노출되는 추천 액티비티 row.
// 필터 없이 가져온 추천 결과의 앞부분 2장을 컴팩트 카드로 보여주고, 탭하면 상세로 이동한다.
struct HomeRecommendationRow: View {
    let items: [MainNewActivity]
    let isLoading: Bool
    let message: String?
    let activityDetailAction: (String) -> Void

    var body: some View {
        Group {
            if isLoading && items.isEmpty {
                placeholder
            } else if items.isEmpty {
                emptyState(text: message ?? "추천 액티비티가 없습니다.")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(items) { item in
                            HomeRecommendationCard(item: item)
                                .frame(
                                    width: HomeRecommendationLayout.cardWidth,
                                    height: HomeRecommendationLayout.cardHeight
                                )
                                .onTapGesture {
                                    activityDetailAction(item.id)
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private var placeholder: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(MainScreenPalette.border)
                        .frame(
                            width: HomeRecommendationLayout.cardWidth,
                            height: HomeRecommendationLayout.cardHeight
                        )
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func emptyState(text: String) -> some View {
        Text(text)
            .font(MainScreenTypography.body)
            .foregroundStyle(MainScreenPalette.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .padding(.horizontal, 20)
    }
}

enum HomeRecommendationLayout {
    static let cardWidth: CGFloat = 200
    static let cardHeight: CGFloat = 252
    static let imageHeight: CGFloat = 132
    // 이미지와 텍스트의 좌측을 정확히 맞춰 카드끼리 시각 정렬을 통일한다.
    static let textInset: CGFloat = 0
    static let stackSpacing: CGFloat = 8
}

private struct HomeRecommendationCard: View {
    let item: MainNewActivity

    var body: some View {
        VStack(alignment: .leading, spacing: HomeRecommendationLayout.stackSpacing) {
            // 이미지 + 좌상단 카테고리 칩(D) + 우상단 Keep 하트(C)
            HomeRecommendationImage(item: item)
                .frame(height: HomeRecommendationLayout.imageHeight)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if let category = item.category {
                        CategoryChip(text: category, color: accentColor(for: category))
                            .padding(.top, 8)
                            .padding(.leading, 8)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if item.isKeep {
                        KeepBadge()
                            .padding(.top, 8)
                            .padding(.trailing, 8)
                    }
                }

            // 텍스트 영역 — 카드 좌우 padding 일관성 (이미지 모서리와 살짝 안쪽 정렬)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .font(MainScreenTypography.activityTitleCompact)
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .lineLimit(1)

                Text(item.location)
                    .font(MainScreenTypography.activityMetaFeatured)
                    .foregroundStyle(MainScreenPalette.textSecondary)
                    .lineLimit(1)

                // B. summary 짧은 설명/태그
                Text(item.summary)
                    .font(MainScreenTypography.bodyCompact)
                    .foregroundStyle(MainScreenPalette.textMuted)
                    .lineLimit(1)

                // A. 가격 — 원가(취소선) + 최종가 + 할인율
                priceRow
                    .padding(.top, 2)
            }
            .padding(.horizontal, HomeRecommendationLayout.textInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var priceRow: some View {
        HStack(spacing: 4) {
            if let originalPrice = item.originalPrice {
                Text(originalPrice)
                    .font(MainScreenTypography.bodyCompact)
                    .foregroundStyle(MainScreenPalette.textMuted)
                    .strikethrough()
            }

            Text(item.finalPrice)
                .font(MainScreenTypography.activityPriceCompact)
                .foregroundStyle(MainScreenPalette.textPrimary)

            if let discountRate = item.discountRate {
                Text(discountRate)
                    .font(MainScreenTypography.activityPriceCompact)
                    .foregroundStyle(MainScreenPalette.primaryBlue)
            }
        }
    }

    // 카테고리 라벨로 강조색을 lookup. 매칭 안 되면 primaryBlue로 폴백.
    private func accentColor(for category: String) -> Color {
        MainCategoryFilter.samples.first { $0.title == category }?.accentColor
            ?? MainScreenPalette.primaryBlue
    }
}

private struct CategoryChip: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(MainScreenTypography.activityMetaCompact)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule(style: .continuous).fill(color))
    }
}

private struct KeepBadge: View {
    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(MainScreenPalette.primaryBlue)
            .padding(7)
            .background(Circle().fill(.white.opacity(0.95)))
            .shadow(color: Color.black.opacity(0.10), radius: 4, y: 2)
    }
}

private struct HomeRecommendationImage: View {
    let item: MainNewActivity
    @Environment(\.imageLoader) private var imageLoader
    @State private var remoteImage: UIImage?
    @State private var didFail = false

    var body: some View {
        ZStack {
            if let remoteImage {
                Image(uiImage: remoteImage)
                    .resizable()
                    .scaledToFill()
            } else if let request = item.imageRequest, !didFail {
                Color(MainScreenPalette.border)
                    .task(id: request.url?.absoluteString) {
                        await load(request: request)
                    }
            } else {
                Image(item.imageName)
                    .resizable()
                    .scaledToFill()
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private func load(request: URLRequest) async {
        do {
            // 카드 표시 영역(약 200×280pt) 기준 다운샘플링
            let pointSize = CGSize(width: 200, height: 280)
            let image: UIImage
            if let imageLoader {
                image = try await imageLoader.loadImage(request, pointSize: pointSize)
            } else {
                image = try await RemoteImageLoader.load(request: request, pointSize: pointSize)
            }
            remoteImage = image
        } catch {
            didFail = true
        }
    }
}
