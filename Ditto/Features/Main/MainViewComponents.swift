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
    // 영상 피드 진입과 검색 시트 진입을 외부에서 주입받아 MainView가 화면 전환을 책임지게 한다.
    var openVideoFeedAction: () -> Void = {}
    var searchAction: () -> Void = {}

    var body: some View {
        HStack {
            TopBarIconButton(systemName: "play.rectangle.fill", action: openVideoFeedAction)

            Spacer()

            // Playfair Italic 폴백 — 번들 폰트 미등록 시 system serif italic으로 표시
            Text("Ditto")
                .font(.system(size: 26, design: .serif))
                .italic()
                .foregroundStyle(MainScreenPalette.textPrimary)

            Spacer()

            TopBarIconButton(systemName: "magnifyingglass", action: searchAction)
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

// 2×5 그리드의 카테고리 아이콘. 각 셀은 컬러 캡슐 + 선택 링 + 활성 닷으로 구성된다.
struct CategoryIconGrid: View {
    let items: [MainCategoryFilter]
    @Binding var selectedID: String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(items) { item in
                Button {
                    selectedID = item.id
                } label: {
                    CategoryIconCell(item: item, isSelected: item.id == selectedID)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
    }
}

private struct CategoryIconCell: View {
    let item: MainCategoryFilter
    let isSelected: Bool
    // 선택 시점에만 증가시키는 트리거. deselect 시에는 변하지 않아 bounce가 일어나지 않는다.
    @State private var bounceTrigger = 0

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // 컬러 캡슐 — 카테고리 강조색의 옅은 톤. 선택 시 캡슐 자체가 진해진다.
                Circle()
                    .fill(item.accentColor.opacity(isSelected ? 0.32 : 0.18))
                    .frame(width: 52, height: 52)

                // 선택 링 — opacity와 scale로 spring 등장
                Circle()
                    .strokeBorder(item.accentColor, lineWidth: 2)
                    .frame(width: 52, height: 52)
                    .scaleEffect(isSelected ? 1.0 : 0.85)
                    .opacity(isSelected ? 1 : 0)

                Image(systemName: item.sfSymbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(item.accentColor)
                    .symbolEffect(.bounce, value: bounceTrigger)
            }
            .scaleEffect(isSelected ? 1.08 : 1.0)
            .animation(.spring(response: 0.32, dampingFraction: 0.6), value: isSelected)
            .onChange(of: isSelected) { _, newValue in
                // 선택으로 전환되는 순간에만 bounce를 1회 트리거. 해제 시에는 트리거하지 않는다.
                if newValue {
                    bounceTrigger += 1
                }
            }

            Text(item.title)
                .font(MainScreenTypography.category)
                .foregroundStyle(
                    isSelected ? MainScreenPalette.textPrimary : MainScreenPalette.textSecondary
                )
                .lineLimit(1)

            // 활성 닷 — 선택 시에만 표시되는 작은 강조점. scale로 spring 등장.
            Circle()
                .fill(item.accentColor)
                .frame(width: 4, height: 4)
                .scaleEffect(isSelected ? 1.0 : 0.1)
                .opacity(isSelected ? 1 : 0)
                .animation(.spring(response: 0.3, dampingFraction: 0.55), value: isSelected)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
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
