//
//  SearchView.swift
//  Ditto
//
//  Created by Codex on 4/28/26.
//

import SwiftUI

struct SearchView: View {
    private let activityDetailAction: (String) -> Void

    @State private var searchText = ""
    @State private var viewModel: SearchViewModel

    init(authManager: any AuthManaging, activityDetailAction: @escaping (String) -> Void) {
        self.activityDetailAction = activityDetailAction
        _viewModel = State(initialValue: SearchViewModel(authManager: authManager))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MainTopBar()
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                titleRow
                    .padding(.top, 2)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        SearchInputField(text: $searchText)
                            .padding(.top, 8)

                        SearchSectionHeader(title: "카테고리")
                            .padding(.top, 18)

                        SearchCategoryGrid(items: SearchCategory.samples)
                            .padding(.top, 10)

                        SearchSectionHeader(title: "추천 액티비티")
                            .padding(.top, 28)

                        SearchRecommendationContent(
                            items: viewModel.recommendedActivities,
                            isLoading: viewModel.isLoadingRecommendedActivities,
                            message: viewModel.recommendedActivitiesMessage,
                            activityDetailAction: activityDetailAction
                        )
                        .padding(.top, 10)
                    }
                    .padding(.bottom, SearchLayout.tabBarContentPadding)
                }
            }
            .navigationDestination(for: SearchCategory.self) { category in
                SearchCategoryActivityListView(
                    category: category,
                    viewModel: viewModel,
                    activityDetailAction: activityDetailAction
                )
            }
            .task {
                await viewModel.loadRecommendedActivities()
            }
        }
    }

    private var titleRow: some View {
        HStack {
            Text("검색")
                .font(MainFont.pretendard(.bold, size: 24))
                .foregroundStyle(MainScreenPalette.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(height: 32)
    }
}

enum SearchLayout {
    static let tabBarContentPadding: CGFloat = 96
}

private struct SearchInputField: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(MainScreenPalette.textSecondary)

            TextField("내 액티비티를 검색해보세요.", text: $text)
                .font(MainFont.pretendard(.medium, size: 14))
                .foregroundStyle(MainScreenPalette.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(
            Capsule()
                .fill(MainScreenPalette.surface)
        )
        .overlay(
            Capsule()
                .stroke(MainScreenPalette.primaryBlue, lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
}

struct SearchSectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(MainScreenTypography.sectionTitle)
                .foregroundStyle(MainScreenPalette.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 20)
        .frame(height: 24)
    }
}

private struct SearchCategoryGrid: View {
    let items: [SearchCategory]
    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(items) { item in
                NavigationLink(value: item) {
                    SearchCategoryCard(item: item)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }
}

private struct SearchCategoryCard: View {
    let item: SearchCategory

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(item.backgroundColor)

            Text(item.title)
                .font(MainFont.pretendard(.bold, size: 18))
                .foregroundStyle(.white)
                .padding(.top, 12)
                .padding(.leading, 12)

            Image(item.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: 92, height: 92)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .rotationEffect(.degrees(12))
                .shadow(color: Color.black.opacity(0.16), radius: 4, y: 2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .offset(x: 28, y: 12)
        }
        .frame(height: 86)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityLabel(item.title)
    }
}

private struct SearchRecommendationContent: View {
    let items: [SearchActivity]
    let isLoading: Bool
    let message: String?
    let activityDetailAction: (String) -> Void

    var body: some View {
        if isLoading && items.isEmpty {
            SearchStateCard(title: "추천 액티비티를 불러오는 중입니다.", systemName: "arrow.clockwise")
                .padding(.horizontal, 20)
        } else if items.isEmpty {
            SearchStateCard(
                title: message ?? "추천 액티비티가 없습니다.",
                subtitle: "잠시 후 다시 확인해 주세요.",
                systemName: "sparkles"
            )
            .padding(.horizontal, 20)
        } else {
            SearchRecommendationCarousel(items: items, activityDetailAction: activityDetailAction)
        }
    }
}

private struct SearchRecommendationCarousel: View {
    let items: [SearchActivity]
    let activityDetailAction: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(items) { item in
                    Button {
                        activityDetailAction(item.id)
                    } label: {
                        SearchRecommendationCard(item: item)
                            .frame(width: 263)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

private struct SearchRecommendationCard: View {
    let item: SearchActivity

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topLeading) {
                SearchRemoteImage(
                    request: item.imageRequest,
                    fallbackImageName: item.fallbackImageName,
                    width: 233,
                    height: 120,
                    cornerRadius: 16
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(MainScreenPalette.borderBlue, lineWidth: 4)
                )

                HStack {
                    Text(item.location)
                        .font(MainScreenTypography.activityMetaCompact)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .padding(12)

                SearchStatusTag(text: item.status)
                    .padding(.leading, 12)
                    .padding(.top, 88)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(MainFont.pretendard(.bold, size: 13))
                        .foregroundStyle(MainScreenPalette.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 2) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text(item.keepCount)
                            .font(MainScreenTypography.activityMetaCompact)
                    }
                    .foregroundStyle(MainScreenPalette.textPrimary)
                }

                Text(item.summary)
                    .font(MainScreenTypography.body)
                    .foregroundStyle(MainScreenPalette.textSecondary)
                    .lineSpacing(4)
                    .lineLimit(2)

                HStack(spacing: 6) {
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
        }
        .padding(.top, 3)
        .padding(.leading, 0)
        .padding(.trailing, 10)
        .padding(.bottom, 12)
        .background(MainScreenPalette.surface)
        .accessibilityLabel(item.title)
    }
}

struct SearchCategory: Identifiable, Hashable {
    let id: String
    let title: String
    let navigationTitle: String
    let backgroundColor: Color
    let imageName: String

    static func == (lhs: SearchCategory, rhs: SearchCategory) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static let samples: [SearchCategory] = [
        .init(
            id: "sightseeing",
            title: "관광",
            navigationTitle: "SIGHTSEEING",
            backgroundColor: Color(red: 0.624, green: 0.776, blue: 0.639),
            imageName: "SearchCategorySightseeing"
        ),
        .init(
            id: "tour",
            title: "투어",
            navigationTitle: "TOUR",
            backgroundColor: Color(red: 0.290, green: 0.090, blue: 0.949),
            imageName: "SearchCategoryTour"
        ),
        .init(
            id: "package",
            title: "패키지",
            navigationTitle: "PACKAGE",
            backgroundColor: Color(red: 0.918, green: 0.145, blue: 0.290),
            imageName: "SearchCategoryPackage"
        ),
        .init(
            id: "exciting",
            title: "익사이팅",
            navigationTitle: "EXCITING",
            backgroundColor: Color(red: 0.941, green: 0.420, blue: 0.090),
            imageName: "SearchCategoryExciting"
        ),
        .init(
            id: "experience",
            title: "체험",
            navigationTitle: "EXPERIENCE",
            backgroundColor: Color(red: 0.231, green: 0.549, blue: 1.000),
            imageName: "SearchCategoryExperience"
        ),
        .init(
            id: "random",
            title: "랜덤",
            navigationTitle: "RANDOM",
            backgroundColor: Color(red: 0.722, green: 0.294, blue: 0.886),
            imageName: "SearchCategoryRandom"
        )
    ]
}

#Preview {
    SearchView(authManager: AuthManager()) { _ in }
}
