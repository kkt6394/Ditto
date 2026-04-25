//
//  PostModels.swift
//  Ditto
//
//  Created by Codex on 4/25/26.
//

import Foundation

struct PostFileUploadRequestDTO: Equatable {
    let files: [MultipartFile]
}

struct PostRequestDTO: Encodable, Equatable {
    let country: String
    let category: String
    let title: String
    let content: String
    let activityId: String?
    let latitude: Double
    let longitude: Double
    let files: [String]?

    enum CodingKeys: String, CodingKey {
        case country
        case category
        case title
        case content
        case activityId = "activity_id"
        case latitude
        case longitude
        case files
    }
}

struct PostUpdateRequestDTO: Encodable, Equatable {
    let country: String?
    let category: String?
    let title: String?
    let content: String?
    let activityId: String?
    let latitude: Double?
    let longitude: Double?
    let files: [String]?

    enum CodingKeys: String, CodingKey {
        case country
        case category
        case title
        case content
        case activityId = "activity_id"
        case latitude
        case longitude
        case files
    }
}

struct CommentRequestDTO: Encodable, Equatable {
    let parentCommentId: String?
    let content: String

    enum CodingKeys: String, CodingKey {
        case parentCommentId = "parent_comment_id"
        case content
    }
}

struct CommentUpdateRequestDTO: Encodable, Equatable {
    let content: String
}

struct PostLikeRequestDTO: Encodable, Equatable {
    let likeStatus: Bool

    enum CodingKeys: String, CodingKey {
        case likeStatus = "like_status"
    }
}

struct PostGeolocationQuery: Equatable {
    let country: String?
    let category: String?
    let longitude: Double?
    let latitude: Double?
    let maxDistance: Int?
    let limit: Int?
    let next: String?
    let orderBy: String?
}

struct PostUserListQuery: Equatable {
    let country: String?
    let category: String?
    let userId: String
    let limit: Int?
    let next: String?
}

struct PostLikedListQuery: Equatable {
    let country: String?
    let category: String?
    let next: String?
    let limit: Int?
}

struct Geolocation: Decodable, Equatable {
    let longitude: Double
    let latitude: Double
}

struct FileResponseDTO: Decodable, Equatable {
    let files: [String]
}

struct CommentReplyResponseDTO: Decodable, Equatable {
    let commentId: String
    let content: String
    let createdAt: String
    let creator: UserInfoResponseDTO
}

struct PostCommentResponseDTO: Decodable, Equatable {
    let commentId: String
    let content: String
    let createdAt: String
    let creator: UserInfoResponseDTO
    let replies: [CommentReplyResponseDTO]
}

struct CommentResponseDTO: Decodable, Equatable {
    let commentId: String
    let content: String
    let createdAt: String
    let creator: UserInfoResponseDTO
}

struct PostLikeResponseDTO: Decodable, Equatable {
    let likeStatus: Bool
}

struct PostResponseDTO: Decodable, Equatable {
    let postId: String
    let country: String
    let category: String
    let title: String
    let content: String
    let activity: ActivitySummaryPostResponseDTO?
    let geolocation: Geolocation
    let creator: UserInfoResponseDTO
    let files: [String]
    let isLike: Bool
    let likeCount: Double
    let comments: [PostCommentResponseDTO]
    let createdAt: String
    let updatedAt: String
}

struct PostListResponseDTO: Decodable, Equatable {
    let data: [PostResponseDTO]
    let nextCursor: String
}

struct PostSummaryResponseDTO: Decodable, Equatable {
    let postId: String
    let country: String
    let category: String
    let title: String
    let content: String
    let activity: ActivitySummaryPostResponseDTO?
    let geolocation: Geolocation
    let creator: UserInfoResponseDTO
    let files: [String]
    let isLike: Bool
    let likeCount: Double
    let createdAt: String
    let updatedAt: String
}

struct PostSummaryPaginationResponseDTO: Decodable, Equatable {
    let data: [PostSummaryResponseDTO]
    let nextCursor: String
}

struct PostSummaryListResponseDTO: Decodable, Equatable {
    let data: [PostSummaryResponseDTO]
}
