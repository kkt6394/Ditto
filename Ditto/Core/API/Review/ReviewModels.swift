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

struct ReviewListQuery: Equatable {
    let activityId: String
    let next: String?
    let limit: Int?
    let orderBy: String?
}

struct UserReviewListQuery: Equatable {
    let userId: String
    let country: String?
    let category: String?
    let next: String?
    let limit: Int?
}

struct ReviewResponseDTO: Decodable, Equatable {
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
