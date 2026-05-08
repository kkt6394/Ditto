//
//  NewActivityComponents.swift
//  Ditto
//
//  Created by Codex on 5/8/26.
//

import SwiftUI
import UIKit

// 홈 상단의 NEW 액티비티 carousel 계통.
// 카드 한 장 + 좌우 슬쩍 보이는 다음/이전 카드. 중앙 카드는 1.0 스케일, 양옆은 살짝 줄어들고 흐려진다.
struct NewActivityCarousel: View {
    let items: [MainNewActivity]
    let activityDetailAction: (String) -> Void
    private let cardWidth: CGFloat = 316
    private let cardHeight: CGFloat = 316
    private let cardSpacing: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            let sideInset = max((proxy.size.width - cardWidth) / 2, 20)
            let viewportCenterX = proxy.frame(in: .global).midX

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: cardSpacing) {
                    ForEach(items) { item in
                        NewActivityCard(item: item)
                            .frame(width: cardWidth, height: cardHeight)
                            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .onTapGesture {
                                activityDetailAction(item.id)
                            }
                            .visualEffect { content, geometry in
                                let cardCenterX = geometry.frame(in: .global).midX
                                let distance = abs(cardCenterX - viewportCenterX)
                                let progress = min(distance / cardWidth, 1)
                                let scale = 1 - (progress * 0.133333)

                                return content
                                    .scaleEffect(scale)
                                    .opacity(Double(1 - (progress * 0.08)))
                            }
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, sideInset)
                .padding(.vertical, 12)
            }
            .scrollTargetBehavior(.viewAligned)
        }
        .frame(height: 340)
    }
}

struct NewActivityContent: View {
    let items: [MainNewActivity]
    let isLoading: Bool
    let message: String?
    let activityDetailAction: (String) -> Void

    var body: some View {
        if isLoading && items.isEmpty {
            NewActivityStateCard(
                title: "NEW 액티비티를 불러오는 중입니다.",
                systemName: "arrow.clockwise"
            )
            .padding(.horizontal, 20)
        } else if items.isEmpty {
            NewActivityStateCard(
                title: message ?? "선택한 조건의 NEW 액티비티가 없습니다.",
                subtitle: "다른 나라나 카테고리를 선택해 보세요.",
                systemName: "magnifyingglass"
            )
            .padding(.horizontal, 20)
        } else {
            NewActivityCarousel(items: items, activityDetailAction: activityDetailAction)
        }
    }
}

private struct NewActivityStateCard: View {
    let title: String
    var subtitle: String?
    let systemName: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemName)
                .font(.system(size: 24, weight: .semibold))
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
        .frame(height: 180)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MainScreenPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MainScreenPalette.border, lineWidth: 1)
        )
    }
}

private struct NewActivityCard: View {
    @Environment(KeepStore.self) private var keepStore
    let item: MainNewActivity

    var body: some View {
        ZStack {
            NewActivityImage(item: item)
        }
        .frame(width: 316, height: 316)
        .clipped()
        .overlay(alignment: .topLeading) {
            LocationCapsule(text: item.location)
                .padding(.top, 16)
                .padding(.leading, 16)
        }
        .overlay(alignment: .topTrailing) {
            ActivityKeepHeart(activityId: item.id, size: 36)
                .padding(.top, 16)
                .padding(.trailing, 16)
        }
        .overlay(alignment: .bottomLeading) {
            VStack(alignment: .leading, spacing: 12) {
                Text(item.title)
                    .font(MainScreenTypography.activityTitleFeatured)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                HStack(spacing: 2) {
                    Image(systemName: "wonsign.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)

                    Text(item.finalPrice)
                        .font(MainScreenTypography.activityPriceFeatured)
                        .foregroundStyle(.white)
                }

                Text(item.summary)
                    .font(MainScreenTypography.body)
                    .foregroundStyle(Color.white.opacity(0.92))
                    .lineSpacing(4)
                    .lineLimit(3)
                    .frame(width: 260, alignment: .leading)
            }
            .frame(width: 260, alignment: .leading)
            .padding(.bottom, 20)
            .padding(.leading, 20)
        }
        .frame(width: 316, height: 316)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: MainScreenPalette.shadow, radius: 8, y: 4)
        .onAppear {
            keepStore.registerInitialKeepStatus(
                activityId: item.id,
                isKept: item.isKeep
            )
        }
    }
}

private struct NewActivityImage: View {
    let item: MainNewActivity
    @Environment(\.imageLoader) private var imageLoader
    @State private var remoteImage: UIImage?
    @State private var didFailLoadingRemoteImage = false

    var body: some View {
        if let remoteImage {
            fittedImage(Image(uiImage: remoteImage))
        } else if let imageRequest = item.imageRequest, !didFailLoadingRemoteImage {
            placeholder
                .task(id: imageRequest.url?.absoluteString) {
                    await loadRemoteImage(from: imageRequest)
                }
        } else {
            fallbackImage
        }
    }

    private func fittedImage(_ image: Image) -> some View {
        image
            .resizable()
            .scaledToFill()
            .frame(width: 316, height: 474)
            .offset(y: -31)
    }

    private var fallbackImage: some View {
        fittedImage(Image(item.imageName))
    }

    private var placeholder: some View {
        Rectangle()
            .fill(MainScreenPalette.border)
            .frame(width: 316, height: 316)
    }

    private func loadRemoteImage(from request: URLRequest) async {
        do {
            // NEW 액티비티 카드 표시 크기(316×474) 기준 다운샘플링
            let pointSize = CGSize(width: 316, height: 474)
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

private struct LocationCapsule: View {
    let text: String

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "location.fill")
                .font(.system(size: 12, weight: .medium))

            Text(text)
                .font(MainScreenTypography.activityMetaCompact)
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            Color.white.opacity(0.34),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
    }
}
