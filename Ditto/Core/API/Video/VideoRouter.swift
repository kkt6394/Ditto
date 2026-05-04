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
            // next가 nil이면 키 자체를 빼서 서버가 처음부터 조회하도록 한다.
            return [
                query.next.map { URLQueryItem(name: "next", value: $0) },
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
