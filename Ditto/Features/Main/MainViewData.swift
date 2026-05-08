//
//  MainViewData.swift
//  Ditto
//
//  Created by 김기태 on 4/25/26.
//

import Foundation
import SwiftUI

struct MainCountryFilter: Identifiable {
    let id: String
    let flag: String
    let name: String

    static let samples: [MainCountryFilter] = [
        .init(id: "korea", flag: "🇰🇷", name: "대한민국"),
        .init(id: "japan", flag: "🇯🇵", name: "일본"),
        .init(id: "australia", flag: "🇦🇺", name: "호주"),
        .init(id: "thailand", flag: "🇹🇭", name: "태국"),
        .init(id: "philippines", flag: "🇵🇭", name: "필리핀")
    ]
}

struct MainCategoryFilter: Identifiable {
    let id: String
    let title: String
    let sfSymbol: String
    let accentColor: Color

    static let samples: [MainCategoryFilter] = [
        .init(
            id: "all",
            title: "전체",
            sfSymbol: "square.grid.3x3.fill",
            accentColor: Color(red: 0.530, green: 0.710, blue: 0.863)
        ),
        .init(
            id: "sightseeing",
            title: "관광",
            sfSymbol: "building.columns.fill",
            accentColor: Color(red: 0.898, green: 0.776, blue: 0.475)
        ),
        .init(
            id: "tour",
            title: "투어",
            sfSymbol: "map.fill",
            accentColor: Color(red: 0.420, green: 0.749, blue: 0.541)
        ),
        .init(
            id: "package",
            title: "패키지",
            sfSymbol: "suitcase.fill",
            accentColor: Color(red: 0.851, green: 0.541, blue: 0.400)
        ),
        .init(
            id: "exciting",
            title: "익사이팅",
            sfSymbol: "bolt.fill",
            accentColor: Color(red: 0.949, green: 0.749, blue: 0.302)
        ),
        .init(
            id: "experience",
            title: "체험",
            sfSymbol: "sparkles",
            accentColor: Color(red: 0.741, green: 0.561, blue: 0.847)
        ),
        .init(
            id: "fitness",
            title: "피트니스",
            sfSymbol: "dumbbell.fill",
            accentColor: Color(red: 0.878, green: 0.451, blue: 0.451)
        ),
        .init(
            id: "beauty",
            title: "뷰티",
            sfSymbol: "leaf.fill",
            accentColor: Color(red: 0.949, green: 0.651, blue: 0.722)
        ),
        .init(
            id: "outdoor",
            title: "아웃도어",
            sfSymbol: "mountain.2.fill",
            accentColor: Color(red: 0.451, green: 0.647, blue: 0.490)
        ),
        .init(
            id: "sports",
            title: "스포츠",
            sfSymbol: "trophy.fill",
            accentColor: Color(red: 0.596, green: 0.510, blue: 0.847)
        )
    ]
}

struct MainNewActivity: Identifiable {
    let id: String
    let countryName: String?
    let latitude: Double?
    let longitude: Double?
    var location: String
    let title: String
    let category: String?
    // 할인 적용 시에만 채워지는 원가(취소선용). 비할인은 nil.
    let originalPrice: String?
    let finalPrice: String
    // "20%" 같은 할인율 문자열. 비할인은 nil.
    let discountRate: String?
    let summary: String
    let imageName: String
    let imageRequest: URLRequest?
    let isKeep: Bool

    static let samples: [MainNewActivity] = [
        .init(
            id: "venice",
            countryName: "캘리포니아",
            latitude: nil,
            longitude: nil,
            location: "캘리포니아, 베니스 비치",
            title: "새싹 스케이트 세션",
            category: "체험",
            originalPrice: "240,000원",
            finalPrice: "209,000원",
            discountRate: "13%",
            summary: "초급자 대상 서핑 느낌의 스케이트보드 입문 클래스. 세계적인 본다이 스케이트 파크에서 프로 강사와 함께하는 볼 스케이팅 체험.",
            imageName: "FigmaMainNewActivity1",
            imageRequest: nil,
            isKeep: false
        ),
        .init(
            id: "jungfrau",
            countryName: "스위스",
            latitude: nil,
            longitude: nil,
            location: "스위스 융프라우",
            title: "겨울 새싹 스키 원정대",
            category: "익사이팅",
            originalPrice: nil,
            finalPrice: "123,000원",
            discountRate: nil,
            summary: "끝없이 펼쳐진 슬로프, 자유롭게 바람을 가르는 시간. 초보자 코스부터 짜릿한 파크존까지, 당신만의 새싹 스키 리듬을 찾아 떠나보세요.",
            imageName: "FigmaMainNewActivity2",
            imageRequest: nil,
            isKeep: false
        ),
        .init(
            id: "ubud",
            countryName: "인도네시아",
            latitude: nil,
            longitude: nil,
            location: "인도네시아, 발리 우붓",
            title: "요가 새싹 선라이즈",
            category: "체험",
            originalPrice: "120,000원",
            finalPrice: "98,000원",
            discountRate: "18%",
            summary: "숲의 결을 따라 천천히 호흡을 맞추는 새벽 요가 클래스. 여행 첫날에도 부담 없이 몸을 깨우기 좋은 감도의 웰니스 액티비티입니다.",
            imageName: "FigmaMainNewActivity3",
            imageRequest: nil,
            isKeep: false
        )
    ]
}

struct MainBanner: Identifiable {
    let id: String
    let name: String
    let imageRequest: URLRequest?
    let payloadType: String
    let payloadValue: String
}

struct MainActivityPost: Identifiable {
    let id: String
    let activityId: String?
    // 피드 카드 하단 미리보기에 쓰는 활동 메타.
    let activityTitle: String?
    let activityCategory: String?
    let activityFinalPrice: String?
    let activityImageRequest: URLRequest?
    let creatorId: String
    let author: String
    let timeText: String
    let title: String
    let body: String
    let location: String
    let category: String
    let profileImageName: String
    let profileImageRequest: URLRequest?
    let mainImageName: String
    let mainImageRequest: URLRequest?
    let subImageTopName: String
    let subImageTopRequest: URLRequest?
    let subImageBottomName: String
    let subImageBottomRequest: URLRequest?
    let media: [MainPostMedia]
    var isLiked: Bool

    static let samples: [MainActivityPost] = [
        .init(
            id: "taipei-snorkeling",
            activityId: "DXWNE",
            activityTitle: "타이페이 스노쿨링 초보자 스쿨 2기",
            activityCategory: "체험",
            activityFinalPrice: "89,000원",
            activityImageRequest: nil,
            creatorId: "sample-user-1",
            author: "씩씩한 새싹이",
            timeText: "1시간 34분 전",
            title: "타이페이 스노쿨링 여행",
            body: "끝없이 펼쳐진 바다를 바라보며, 모든 고민이 잠시 멀어지는 느낌이었다. 잔잔한 파도 소리에 마음까지 편안해졌던 시간.",
            location: "대만 타이페이",
            category: "타이페이 스노쿨링 초보자 스쿨 2기",
            profileImageName: "FigmaMainPostProfile2",
            profileImageRequest: nil,
            mainImageName: "FigmaMainPostHero1",
            mainImageRequest: nil,
            subImageTopName: "FigmaMainPostSub11",
            subImageTopRequest: nil,
            subImageBottomName: "FigmaMainPostSub12",
            subImageBottomRequest: nil,
            media: [
                .image(id: "taipei-snorkeling-0", request: nil, fallbackImageName: "FigmaMainPostHero1"),
                .image(id: "taipei-snorkeling-1", request: nil, fallbackImageName: "FigmaMainPostSub11"),
                .image(id: "taipei-snorkeling-2", request: nil, fallbackImageName: "FigmaMainPostSub12")
            ],
            isLiked: false
        ),
        .init(
            id: "interlaken-paragliding",
            activityId: "DXWNE",
            activityTitle: "알프스 설산 글라이딩 초보자 가이드",
            activityCategory: "익사이팅",
            activityFinalPrice: "240,000원",
            activityImageRequest: nil,
            creatorId: "sample-user-2",
            author: "하늘색 새싹",
            timeText: "3시간 50분 전",
            title: "하늘을 나는 새싹 패러글라이딩",
            body: "처음엔 겁이 났어요. 줄 하나에 매달려 하늘을 난다는 게 상상조차 안 됐거든요. 하지만 이륙하는 순간, 걱정은 모두 사라졌습니다.",
            location: "스위스 인터라켄",
            category: "알프스 설산 글라이딩 초보자 가이드",
            profileImageName: "FigmaMainPostProfile1",
            profileImageRequest: nil,
            mainImageName: "FigmaMainPostHero2",
            mainImageRequest: nil,
            subImageTopName: "FigmaMainPostSub21",
            subImageTopRequest: nil,
            subImageBottomName: "FigmaMainPostSub22",
            subImageBottomRequest: nil,
            media: [
                .image(id: "interlaken-paragliding-0", request: nil, fallbackImageName: "FigmaMainPostHero2"),
                .image(id: "interlaken-paragliding-1", request: nil, fallbackImageName: "FigmaMainPostSub21"),
                .image(id: "interlaken-paragliding-2", request: nil, fallbackImageName: "FigmaMainPostSub22")
            ],
            isLiked: true
        )
    ]
}

struct MainPostMedia: Identifiable {
    enum Kind: Equatable {
        case image
        case video
    }

    let id: String
    let kind: Kind
    let request: URLRequest?
    let fallbackImageName: String
    let videoId: String?

    static func image(id: String, request: URLRequest?, fallbackImageName: String) -> MainPostMedia {
        MainPostMedia(
            id: id,
            kind: .image,
            request: request,
            fallbackImageName: fallbackImageName,
            videoId: nil
        )
    }

    static func video(
        id: String,
        request: URLRequest?,
        fallbackImageName: String,
        videoId: String? = nil
    ) -> MainPostMedia {
        MainPostMedia(
            id: id,
            kind: .video,
            request: request,
            fallbackImageName: fallbackImageName,
            videoId: videoId
        )
    }
}

struct MainTabItem: Identifiable {
    let id: String
    let systemName: String
    let title: String

    static let samples: [MainTabItem] = [
        .init(id: MainTab.home.rawValue, systemName: "house.fill", title: "홈"),
        .init(id: MainTab.feed.rawValue, systemName: "square.grid.2x2.fill", title: "피드"),
        .init(id: MainTab.chat.rawValue, systemName: "bubble.left.and.bubble.right.fill", title: "채팅"),
        .init(id: MainTab.likes.rawValue, systemName: "heart.fill", title: "좋아요"),
        .init(id: MainTab.profile.rawValue, systemName: "person.fill", title: "프로필")
    ]
}

enum MainTab: String {
    case home
    case feed
    case chat
    case likes
    case profile
}
