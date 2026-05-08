//
//  SearchFilterModels.swift
//  Ditto
//
//  Created by Codex on 5/8/26.
//

import SwiftUI

// 검색 시트 안에서 국가 카드를 통해 노출되는 필터.
// 카테고리와 같은 카드 톤이지만 국가 깃발과 톤별 배경색을 사용한다.
struct SearchCountryFilter: Identifiable, Hashable {
    let id: String
    let title: String
    let flag: String
    let backgroundColor: Color

    static let samples: [SearchCountryFilter] = [
        .init(
            id: "korea",
            title: "대한민국",
            flag: "🇰🇷",
            backgroundColor: Color(red: 0.396, green: 0.486, blue: 0.682)
        ),
        .init(
            id: "japan",
            title: "일본",
            flag: "🇯🇵",
            backgroundColor: Color(red: 0.776, green: 0.357, blue: 0.396)
        ),
        .init(
            id: "australia",
            title: "호주",
            flag: "🇦🇺",
            backgroundColor: Color(red: 0.220, green: 0.435, blue: 0.541)
        ),
        .init(
            id: "thailand",
            title: "태국",
            flag: "🇹🇭",
            backgroundColor: Color(red: 0.831, green: 0.482, blue: 0.624)
        ),
        .init(
            id: "philippines",
            title: "필리핀",
            flag: "🇵🇭",
            backgroundColor: Color(red: 0.231, green: 0.557, blue: 0.529)
        )
    ]
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
            backgroundColor: Color(red: 0.773, green: 0.416, blue: 0.231),
            imageName: "SearchCategorySightseeing"
        ),
        .init(
            id: "tour",
            title: "투어",
            navigationTitle: "TOUR",
            backgroundColor: Color(red: 0.176, green: 0.478, blue: 0.420),
            imageName: "SearchCategoryTour"
        ),
        .init(
            id: "package",
            title: "패키지",
            navigationTitle: "PACKAGE",
            backgroundColor: Color(red: 0.176, green: 0.227, blue: 0.290),
            imageName: "SearchCategoryPackage"
        ),
        .init(
            id: "exciting",
            title: "익사이팅",
            navigationTitle: "EXCITING",
            backgroundColor: Color(red: 0.141, green: 0.439, blue: 0.816),
            imageName: "SearchCategoryExciting"
        ),
        .init(
            id: "experience",
            title: "체험",
            navigationTitle: "EXPERIENCE",
            backgroundColor: Color(red: 0.478, green: 0.353, blue: 0.239),
            imageName: "SearchCategoryExperience"
        ),
        .init(
            id: "all",
            title: "전체",
            navigationTitle: "ALL",
            backgroundColor: Color(red: 0.475, green: 0.196, blue: 0.749),
            imageName: "SearchCategoryRandom"
        )
    ]
}
