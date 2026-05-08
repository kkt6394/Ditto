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
                HStack(spacing: 12) {
                    ForEach(items.prefix(2)) { item in
                        HomeRecommendationCard(item: item)
                            .onTapGesture {
                                activityDetailAction(item.id)
                            }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var placeholder: some View {
        HStack(spacing: 12) {
            ForEach(0..<2, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(MainScreenPalette.border)
                    .frame(height: 180)
            }
        }
        .padding(.horizontal, 20)
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

private struct HomeRecommendationCard: View {
    let item: MainNewActivity

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HomeRecommendationImage(item: item)
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Text(item.title)
                .font(MainScreenTypography.activityTitleCompact)
                .foregroundStyle(MainScreenPalette.textPrimary)
                .lineLimit(1)

            Text(item.location)
                .font(MainScreenTypography.activityMetaFeatured)
                .foregroundStyle(MainScreenPalette.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
