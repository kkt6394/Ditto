//
//  MainViewData.swift
//  Ditto
//
//  Created by 김기태 on 4/25/26.
//

import Foundation

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

    static let samples: [MainCategoryFilter] = [
        .init(id: "sightseeing", title: "관광"),
        .init(id: "tour", title: "투어"),
        .init(id: "package", title: "패키지"),
        .init(id: "exciting", title: "익사이팅"),
        .init(id: "experience", title: "체험"),
        .init(id: "random", title: "랜덤")
    ]
}

struct MainNewActivity: Identifiable {
    let id: String
    let location: String
    let title: String
    let price: String
    let summary: String
    let imageName: String
    let imageRequest: URLRequest?

    static let samples: [MainNewActivity] = [
        .init(
            id: "venice",
            location: "캘리포니아, 베니스 비치",
            title: "새싹 스케이트 세션",
            price: "209,000원",
            summary: "초급자 대상 서핑 느낌의 스케이트보드 입문 클래스. 세계적인 본다이 스케이트 파크에서 프로 강사와 함께하는 볼 스케이팅 체험.",
            imageName: "FigmaMainNewActivity1",
            imageRequest: nil
        ),
        .init(
            id: "jungfrau",
            location: "스위스 융프라우",
            title: "겨울 새싹 스키 원정대",
            price: "123,000원",
            summary: "끝없이 펼쳐진 슬로프, 자유롭게 바람을 가르는 시간. 초보자 코스부터 짜릿한 파크존까지, 당신만의 새싹 스키 리듬을 찾아 떠나보세요.",
            imageName: "FigmaMainNewActivity2",
            imageRequest: nil
        ),
        .init(
            id: "ubud",
            location: "인도네시아, 발리 우붓",
            title: "요가 새싹 선라이즈",
            price: "98,000원",
            summary: "숲의 결을 따라 천천히 호흡을 맞추는 새벽 요가 클래스. 여행 첫날에도 부담 없이 몸을 깨우기 좋은 감도의 웰니스 액티비티입니다.",
            imageName: "FigmaMainNewActivity3",
            imageRequest: nil
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
    let isLiked: Bool

    static let samples: [MainActivityPost] = [
        .init(
            id: "taipei-snorkeling",
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
            isLiked: false
        ),
        .init(
            id: "interlaken-paragliding",
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
            isLiked: true
        )
    ]
}

struct MainTabItem: Identifiable {
    let id: String
    let systemName: String
    let title: String

    static let samples: [MainTabItem] = [
        .init(id: MainTab.home.rawValue, systemName: "house.fill", title: "홈"),
        .init(id: MainTab.explore.rawValue, systemName: "safari", title: "탐색"),
        .init(id: MainTab.likes.rawValue, systemName: "heart", title: "좋아요"),
        .init(id: MainTab.profile.rawValue, systemName: "person", title: "프로필")
    ]
}

enum MainTab: String {
    case home
    case explore
    case likes
    case profile
}
