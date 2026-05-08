//
//  MainRoute.swift
//  Ditto
//
//  Created by Codex on 5/5/26.
//

import Foundation

// MainView의 NavigationStack에서 push되는 화면을 구분하는 라우트 enum.
enum MainRoute: Hashable {
    case activityDetail(activityId: String)
    case postDetail(postId: String)
    case chat(roomId: String, opponentNick: String)
    case search
    case searchCategory(SearchCategory)
    case searchCountry(SearchCountryFilter)
    case orderList
    case receipt(
        orderCode: String,
        activityId: String,
        existingReviewId: String?,
        thumbnailPath: String?
    )
    case activityCompose(mode: ActivityComposeMode)
    case activityCardCompose
}
