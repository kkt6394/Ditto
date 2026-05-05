//
//  VideoModels.swift
//  Ditto
//
//  Created by Codex on 4/25/26.
//

import Foundation

struct AdminVideoRegisterRequestDTO: Encodable, Equatable {
    let metadata: JSONValue
    let transcodedFolderName: String
    let title: String?
    let description: String?
    let subtitleLangs: String?
    let availableQualities: [String]?

    enum CodingKeys: String, CodingKey {
        case metadata
        case transcodedFolderName = "transcoded_folder_name"
        case title
        case description
        case subtitleLangs = "subtitle_langs"
        case availableQualities = "available_qualities"
    }
}

struct VideoListQuery: Equatable {
    let next: String?
    let limit: Int?
}

struct VideoLikeRequestDTO: Encodable, Equatable {
    let likeStatus: Bool

    enum CodingKeys: String, CodingKey {
        case likeStatus = "like_status"
    }
}

struct VideoLikeResponseDTO: Decodable, Equatable {
    let likeStatus: Bool
}

struct VideoResponseDTO: Decodable, Equatable {
    let videoId: String
    let fileName: String
    let title: String
    let description: String
    let duration: Double
    let thumbnailUrl: String
    let availableQualities: [String]
    let viewCount: Int
    let likeCount: Int
    let isLiked: Bool
    let createdAt: String
}

struct StreamQualityDTO: Decodable, Equatable {
    let quality: String
    let url: String
}

struct StreamSubtitleDTO: Decodable, Equatable {
    let language: String
    let name: String
    let isDefault: Bool
    let url: String
}

struct StreamUrlResponseDTO: Decodable, Equatable {
    let videoId: String
    let streamUrl: String
    let qualities: [StreamQualityDTO]
    let subtitles: [StreamSubtitleDTO]
}

struct VideoListResponseDTO: Decodable, Equatable {
    let data: [VideoResponseDTO]
    // 다음 페이지가 있을 때만 응답에 포함되므로 옵셔널.
    let nextCursor: String?
}
