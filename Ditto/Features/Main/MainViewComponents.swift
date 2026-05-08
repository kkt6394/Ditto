//
//  MainViewComponents.swift
//  Ditto
//
//  Created by 김기태 on 4/25/26.
//

import SwiftUI
import UIKit

enum MainScreenPalette {
    static let background = Color(red: 0.976, green: 0.976, blue: 0.976)
    static let surface = Color.white
    static let primaryBlue = Color(red: 0.478, green: 0.710, blue: 0.863)
    static let primaryBlueSoft = Color(red: 0.910, green: 0.953, blue: 0.976)
    static let textPrimary = Color(red: 0.263, green: 0.263, blue: 0.278)
    static let textSecondary = Color(red: 0.671, green: 0.671, blue: 0.682)
    static let textMuted = Color(red: 0.847, green: 0.839, blue: 0.843)
    static let border = Color(red: 0.918, green: 0.918, blue: 0.918)
    static let borderBlue = Color(red: 0.839, green: 0.898, blue: 0.918)
    static let shadow = Color.black.opacity(0.12)
    static let glassFill = Color.white.opacity(0.8)
    static let glassStroke = Color.white.opacity(0.6)
    static let overlay = LinearGradient(
        colors: [Color.black.opacity(0.10), Color.black.opacity(0.55)],
        startPoint: .top,
        endPoint: .bottom
    )
}

enum MainScreenTypography {
    static let brand = MainFont.paperlogyBlack(size: 14)
    static let sectionTitle = MainFont.pretendard(.bold, size: 14)
    static let action = MainFont.pretendard(.semibold, size: 12)
    static let country = MainFont.pretendard(.semibold, size: 14)
    static let category = MainFont.pretendard(.medium, size: 13)
    static let activityTitleCompact = MainFont.paperlogyBlack(size: 19)
    static let activityTitleFeatured = MainFont.paperlogyBlack(size: 22)
    static let activityMetaCompact = MainFont.pretendard(.medium, size: 10)
    static let activityMetaFeatured = MainFont.pretendard(.medium, size: 12)
    static let activityPriceCompact = MainFont.paperlogyBlack(size: 12)
    static let activityPriceFeatured = MainFont.paperlogyBlack(size: 14)
    static let body = MainFont.pretendard(.regular, size: 12)
    static let bodyCompact = MainFont.pretendard(.regular, size: 10)
    static let author = MainFont.pretendard(.semibold, size: 12)
    static let timestamp = MainFont.pretendard(.medium, size: 10)
    static let postTitle = MainFont.pretendard(.bold, size: 13)
    static let postBody = MainFont.pretendard(.regular, size: 12)
    static let chip = MainFont.pretendard(.semibold, size: 12)
    static let distance = MainFont.pretendard(.bold, size: 13)
    static let tab = MainFont.pretendard(.medium, size: 11)
}

struct MainTopBar: View {
    // 영상 피드 진입은 외부에서 주입받아 화면 전환 흐름은 MainView가 책임지게 한다.
    var openVideoFeedAction: () -> Void = {}

    var body: some View {
        HStack {
            Text("DITTO")
                .font(MainScreenTypography.brand)
                .foregroundStyle(MainScreenPalette.primaryBlue)

            Spacer()

            HStack(spacing: 12) {
                TopBarIconButton(systemName: "play.rectangle.fill", action: openVideoFeedAction)
                TopBarIconButton(systemName: "bell")
                TopBarIconButton(systemName: "magnifyingglass")
            }
        }
        .frame(height: 56)
    }
}

private struct TopBarIconButton: View {
    let systemName: String
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 19, weight: .medium))
                .foregroundStyle(MainScreenPalette.textPrimary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
    }
}

struct CountryFilterCarousel: View {
    let items: [MainCountryFilter]
    @Binding var selectedID: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    Button {
                        selectedID = item.id
                    } label: {
                        CountryFilterCard(
                            item: item,
                            isSelected: item.id == selectedID
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 4)
        }
    }
}

private struct CountryFilterCard: View {
    let item: MainCountryFilter
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(item.flag)
                .font(.system(size: 30))

            Text(item.name)
                .font(MainScreenTypography.country)
                .foregroundStyle(isSelected ? MainScreenPalette.primaryBlue : MainScreenPalette.textSecondary)
        }
        .frame(width: 116, height: 52)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? MainScreenPalette.primaryBlueSoft : MainScreenPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isSelected ? MainScreenPalette.borderBlue : MainScreenPalette.border, lineWidth: 1)
        )
    }
}

struct CategoryFilterCarousel: View {
    let items: [MainCategoryFilter]
    @Binding var selectedID: String

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                ForEach(items) { item in
                    Button {
                        selectedID = item.id
                    } label: {
                        Text(item.title)
                            .font(MainScreenTypography.category)
                            .foregroundStyle(
                                item.id == selectedID
                                    ? MainScreenPalette.primaryBlue
                                    : MainScreenPalette.textSecondary
                            )
                            .padding(.horizontal, 18)
                            .frame(height: 32)
                            .background(
                                Capsule()
                                    .fill(MainScreenPalette.surface)
                            )
                            .overlay(
                                Capsule()
                                    .stroke(
                                        item.id == selectedID ? MainScreenPalette.borderBlue : MainScreenPalette.border,
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 20)
            .padding(.trailing, 20)
            .padding(.vertical, 4)
        }
    }
}

struct MainSectionTitleRow: View {
    let title: String

    var body: some View {
        HStack(alignment: .bottom) {
            Text(title)
                .font(MainScreenTypography.sectionTitle)
                .foregroundStyle(MainScreenPalette.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

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

                    Text(item.price)
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
