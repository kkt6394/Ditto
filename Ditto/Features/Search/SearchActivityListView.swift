//
//  SearchActivityListView.swift
//  Ditto
//
//  Created by Codex on 4/28/26.
//

import SwiftUI

struct SearchCategoryActivityListView: View {
    let category: SearchCategory
    let viewModel: SearchViewModel

    var body: some View {
        VStack(spacing: 0) {
            SearchCategoryNavigationBar(title: category.navigationTitle)

            SearchSectionHeader(title: "\(category.title) 액티비티")
                .padding(.top, 8)

            SearchCategoryActivityContent(
                items: viewModel.categoryActivities,
                isLoading: viewModel.isLoadingCategoryActivities,
                message: viewModel.categoryActivitiesMessage
            )
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(MainScreenPalette.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: category.id) {
            await viewModel.loadCategoryActivities(category: category.title)
        }
    }
}

private struct SearchCategoryNavigationBar: View {
    @Environment(\.dismiss) private var dismiss
    let title: String

    var body: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(title)
                .font(MainScreenTypography.brand)
                .foregroundStyle(MainScreenPalette.primaryBlue)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 4)
        .frame(height: 44)
    }
}

private struct SearchCategoryActivityContent: View {
    let items: [SearchActivity]
    let isLoading: Bool
    let message: String?

    var body: some View {
        if isLoading && items.isEmpty {
            SearchStateCard(title: "액티비티를 불러오는 중입니다.", systemName: "arrow.clockwise")
                .padding(.horizontal, 20)
        } else if items.isEmpty {
            SearchStateCard(
                title: message ?? "액티비티가 없습니다.",
                subtitle: "다른 카테고리를 선택해 보세요.",
                systemName: "magnifyingglass"
            )
            .padding(.horizontal, 20)
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        SearchActivityListCard(item: item)

                        if index != items.indices.last {
                            Divider()
                                .padding(.horizontal, 20)
                                .overlay(MainScreenPalette.border)
                        }
                    }
                }
                .padding(.bottom, SearchLayout.tabBarContentPadding)
            }
        }
    }
}

private struct SearchActivityListCard: View {
    let item: SearchActivity

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                SearchRemoteImage(
                    request: item.imageRequest,
                    fallbackImageName: item.fallbackImageName,
                    width: 350,
                    height: 180,
                    cornerRadius: 12
                )

                HStack {
                    LikeCircle(isSelected: item.isKeep)
                    Spacer()
                    SearchLocationTag(text: item.location)
                }
                .padding(.top, 8)
                .padding(.horizontal, 12)

                if item.isAdvertisement {
                    Text("AD")
                        .font(MainScreenTypography.activityMetaCompact)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .frame(height: 16)
                        .background(Color.white.opacity(0.16), in: Capsule())
                        .padding(.top, 156)
                        .padding(.leading, 300)
                }

                SearchStatusBanner(status: item.status, detail: item.statusDetail)
                    .padding(.top, 164)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Text(item.title)
                        .font(MainFont.pretendard(.bold, size: 16))
                        .foregroundStyle(MainScreenPalette.textPrimary)
                        .lineLimit(1)

                    SearchMetricLabel(systemName: "heart.fill", text: item.keepCount)
                    SearchMetricLabel(systemName: "leaf.fill", text: item.pointText)
                }

                Text(item.summary)
                    .font(MainScreenTypography.body)
                    .foregroundStyle(MainScreenPalette.textSecondary)
                    .lineSpacing(4)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let originalPrice = item.originalPrice {
                        Text(originalPrice)
                            .font(MainScreenTypography.bodyCompact)
                            .foregroundStyle(MainScreenPalette.textMuted)
                            .strikethrough()
                    }

                    Text(item.finalPrice)
                        .font(MainFont.pretendard(.bold, size: 14))
                        .foregroundStyle(MainScreenPalette.textPrimary)

                    if let discountRate = item.discountRate {
                        Text(discountRate)
                            .font(MainFont.pretendard(.bold, size: 14))
                            .foregroundStyle(MainScreenPalette.primaryBlue)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(MainScreenPalette.surface)
    }
}
