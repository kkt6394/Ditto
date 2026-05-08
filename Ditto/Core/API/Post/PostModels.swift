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

// 위치기반 게시글 조회 정렬 기준. rawValue가 그대로 order_by 쿼리로 전송된다.
enum PostOrderBy: String, Equatable {
    case createdAt
    case likes
}

struct PostGeolocationQuery: Equatable {
    let country: String?
    let category: String?
    let longitude: Double?
    let latitude: Double?
    let maxDistance: Int?
    let limit: Int?
    let next: String?
    let orderBy: PostOrderBy?
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

extension Array where Element == PostCommentResponseDTO {
    // 원 댓글 + 모든 대댓글의 합. PostDetail 헤더와 피드 카드 갯수가 같은 기준을 쓰도록 통일.
    var totalCommentCount: Int {
        reduce(0) { $0 + 1 + $1.replies.count }
    }
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
