//
//  ReviewModels.swift
//  Ditto
//
//  Created by Codex on 4/25/26.
//

import Foundation

struct ReviewFileUploadRequestDTO: Equatable {
    let files: [MultipartFile]
}

struct ReviewCreateRequestDTO: Encodable, Equatable {
    let content: String
    let rating: Int
    let reviewImageUrls: [String]?
    let orderCode: String

    enum CodingKeys: String, CodingKey {
        case content
        case rating
        case reviewImageUrls = "review_image_urls"
        case orderCode = "order_code"
    }
}

struct ReviewUpdateRequestDTO: Encodable, Equatable {
    let content: String?
    let rating: Int?
    let reviewImageUrls: [String]?

    enum CodingKeys: String, CodingKey {
        case content
        case rating
        case reviewImageUrls = "review_image_urls"
    }
}

// 액티비티 리뷰 목록 정렬 기준. rawValue가 그대로 order_by 쿼리로 전송된다.
enum ReviewOrderBy: String, Equatable {
    case latest
    case ratingHigh = "rating_high"
    case ratingLow = "rating_low"
}

struct ReviewListQuery: Equatable {
    let activityId: String
    let next: String?
    let limit: Int?
    let orderBy: ReviewOrderBy?
}

struct UserReviewListQuery: Equatable {
    let userId: String
    let country: String?
    let category: String?
    let next: String?
    let limit: Int?
}

struct ReviewResponseDTO: Decodable, Equatable, Identifiable {
    let reviewId: String
    let content: String
    let rating: Int
    let reviewImageUrls: [String]
    let reservationItemName: String
    let reservationItemTime: String
    let creator: UserInfoResponseDTO
    let userTotalReviewCount: Int
    let userTotalRating: Double
    let createdAt: String
    let updatedAt: String

    // .sheet(item:)에 직접 바인딩하기 위해 reviewId를 id로 사용한다.
    var id: String { reviewId }
}

struct ReviewListResponseDTO: Decodable, Equatable {
    let data: [ReviewResponseDTO]
    let nextCursor: String
}

struct ReviewImageResponseDTO: Decodable, Equatable {
    let reviewImageUrls: [String]
}

struct ReviewRatingResponseDTO: Decodable, Equatable {
    let rating: Int
    let count: Int
}

struct ReviewRatingListResponseDTO: Decodable, Equatable {
    let data: [ReviewRatingResponseDTO]
}

struct UserReviewResponseDTO: Decodable, Equatable {
    let reviewId: String
    let content: String
    let rating: Int
    let activity: ActivitySummaryPostResponseDTO
    let reviewImageUrls: [String]
    let reservationItemName: String
    let reservationItemTime: String
    let creator: UserInfoResponseDTO
    let createdAt: String
    let updatedAt: String
}

struct UserReviewListResponseDTO: Decodable, Equatable {
    let data: [UserReviewResponseDTO]
    let nextCursor: String
}
