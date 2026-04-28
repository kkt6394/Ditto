//
//  MainBannerComponents.swift
//  Ditto
//
//  Created by Codex on 4/28/26.
//

import SwiftUI
import UIKit

struct MainBannerContent: View {
    let banners: [MainBanner]
    let isLoading: Bool
    let message: String?

    var body: some View {
        if isLoading && banners.isEmpty {
            MainBannerStateCard()
                .padding(.horizontal, 20)
        } else if !banners.isEmpty {
            MainBannerCarousel(banners: banners)
        }
    }
}

private struct MainBannerCarousel: View {
    let banners: [MainBanner]
    private let bannerHeight: CGFloat = 104
    @State private var selectedBannerID: String?

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(banners) { banner in
                            MainBannerCard(
                                banner: banner,
                                width: proxy.size.width,
                                height: bannerHeight
                            )
                            .frame(width: proxy.size.width, height: bannerHeight)
                            .id(banner.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollPosition(id: $selectedBannerID)
                .scrollTargetBehavior(.paging)

                MainBannerPageBadge(
                    currentPage: currentPage,
                    totalPage: banners.count
                )
                .padding(.trailing, 14)
                .padding(.bottom, 10)
            }
        }
        .onAppear {
            selectedBannerID = selectedBannerID ?? banners.first?.id
        }
        .onChange(of: banners.map(\.id)) { _, newIDs in
            guard let selectedBannerID, newIDs.contains(selectedBannerID) else {
                self.selectedBannerID = newIDs.first
                return
            }
        }
        .frame(height: bannerHeight)
        .accessibilityLabel("메인 배너")
    }

    private var currentPage: Int {
        guard let selectedBannerID,
              let index = banners.firstIndex(where: { $0.id == selectedBannerID }) else {
            return banners.isEmpty ? 0 : 1
        }

        return index + 1
    }
}

private struct MainBannerPageBadge: View {
    let currentPage: Int
    let totalPage: Int

    var body: some View {
        Text("\(currentPage) / \(totalPage)")
            .font(MainScreenTypography.bodyCompact)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(
                Color.black.opacity(0.42),
                in: Capsule()
            )
    }
}

private struct MainBannerCard: View {
    let banner: MainBanner
    let width: CGFloat
    let height: CGFloat
    @State private var remoteImage: UIImage?
    @State private var didFailLoadingRemoteImage = false

    var body: some View {
        ZStack(alignment: .leading) {
            if let remoteImage {
                bannerImage(Image(uiImage: remoteImage))
            } else if let imageRequest = banner.imageRequest, !didFailLoadingRemoteImage {
                placeholder
                    .task(id: imageRequest.url?.absoluteString) {
                        await loadRemoteImage(from: imageRequest)
                    }
            } else {
                fallback
            }

            if remoteImage == nil || didFailLoadingRemoteImage {
                Text(banner.name)
                    .font(MainScreenTypography.sectionTitle)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .padding(.horizontal, 18)
            }
        }
        .clipped()
        .accessibilityLabel(banner.name)
    }

    private func bannerImage(_ image: Image) -> some View {
        image
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipped()
    }

    private var placeholder: some View {
        Rectangle()
            .fill(MainScreenPalette.border)
            .frame(width: width, height: height)
            .overlay(alignment: .leading) {
                ProgressView()
                    .tint(MainScreenPalette.primaryBlue)
                    .padding(.leading, 18)
            }
    }

    private var fallback: some View {
        LinearGradient(
            colors: [
                MainScreenPalette.primaryBlue,
                Color(red: 0.294, green: 0.498, blue: 0.655)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(width: width, height: height)
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

private struct MainBannerStateCard: View {
    var body: some View {
        Rectangle()
            .fill(MainScreenPalette.surface)
            .frame(height: 104)
            .overlay {
                ProgressView()
                    .tint(MainScreenPalette.primaryBlue)
            }
    }
}
