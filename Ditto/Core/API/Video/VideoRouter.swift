//
//  VideoRouter.swift
//  Ditto
//
//  Created by Codex on 4/25/26.
//

import Foundation

enum VideoRouter: APIRouter {
    case list(VideoListQuery)
    case stream(videoId: String)
    case like(videoId: String, request: VideoLikeRequestDTO)
}

extension VideoRouter {
    var path: String {
        switch self {
        case .list:
            return "v1/videos"
        case .stream(let videoId):
            return "v1/videos/\(videoId)/stream"
        case .like(let videoId, _):
            return "v1/videos/\(videoId)/like"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list, .stream:
            return .get
        case .like:
            return .post
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .list(let query):
            return [
                URLQueryItem(name: "next", value: query.next),
                query.limit.map { URLQueryItem(name: "limit", value: String($0)) }
            ]
            .compactMap { $0 }
        case .stream, .like:
            return []
        }
    }

    var body: Encodable? {
        switch self {
        case .like(_, let request):
            return request
        case .list, .stream:
            return nil
        }
    }

    var requiresAuthentication: Bool {
        true
    }
}
