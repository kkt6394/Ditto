//
//  PostRouter.swift
//  Ditto
//
//  Created by Codex on 4/25/26.
//

import Foundation

enum PostRouter: APIRouter {
    case uploadFiles(PostFileUploadRequestDTO)
    case create(PostRequestDTO)
    case geolocation(PostGeolocationQuery)
    case search(title: String)
    case detail(postId: String)
    case update(postId: String, request: PostUpdateRequestDTO)
    case delete(postId: String)
    case createComment(postId: String, request: CommentRequestDTO)
    case updateComment(postId: String, commentId: String, request: CommentUpdateRequestDTO)
    case deleteComment(postId: String, commentId: String)
    case like(postId: String, request: PostLikeRequestDTO)
    case userPosts(PostUserListQuery)
    case likedPosts(PostLikedListQuery)
}

extension PostRouter {
    var path: String {
        switch self {
        case .uploadFiles:
            return "v1/posts/files"
        case .create:
            return "v1/posts"
        case .geolocation:
            return "v1/posts/geolocation"
        case .search:
            return "v1/posts/search"
        case .detail(let postId), .update(let postId, _), .delete(let postId):
            return "v1/posts/\(postId)"
        case .createComment(let postId, _):
            return "v1/posts/\(postId)/comments"
        case .updateComment(let postId, let commentId, _),
             .deleteComment(let postId, let commentId):
            return "v1/posts/\(postId)/comments/\(commentId)"
        case .like(let postId, _):
            return "v1/posts/\(postId)/like"
        case .userPosts(let query):
            return "v1/posts/users/\(query.userId)"
        case .likedPosts:
            return "v1/posts/likes/me"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .geolocation, .search, .detail, .userPosts, .likedPosts:
            return .get
        case .update, .updateComment:
            return .put
        case .delete, .deleteComment:
            return .delete
        case .uploadFiles, .create, .createComment, .like:
            return .post
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .geolocation(let query):
            return [
                URLQueryItem(name: "country", value: query.country),
                URLQueryItem(name: "category", value: query.category),
                query.longitude.map { URLQueryItem(name: "longitude", value: String($0)) },
                query.latitude.map { URLQueryItem(name: "latitude", value: String($0)) },
                query.maxDistance.map { URLQueryItem(name: "maxDistance", value: String($0)) },
                query.limit.map { URLQueryItem(name: "limit", value: String($0)) },
                URLQueryItem(name: "next", value: query.next),
                URLQueryItem(name: "order_by", value: query.orderBy)
            ]
            .compactMap { $0 }
        case .search(let title):
            return [URLQueryItem(name: "title", value: title)]
        case .userPosts(let query):
            return [
                URLQueryItem(name: "country", value: query.country),
                URLQueryItem(name: "category", value: query.category),
                query.limit.map { URLQueryItem(name: "limit", value: String($0)) },
                URLQueryItem(name: "next", value: query.next)
            ]
            .compactMap { $0 }
        case .likedPosts(let query):
            return [
                URLQueryItem(name: "country", value: query.country),
                URLQueryItem(name: "category", value: query.category),
                URLQueryItem(name: "next", value: query.next),
                query.limit.map { URLQueryItem(name: "limit", value: String($0)) }
            ]
            .compactMap { $0 }
        case .uploadFiles, .create, .detail, .update, .delete, .createComment,
             .updateComment, .deleteComment, .like:
            return []
        }
    }

    var body: Encodable? {
        switch self {
        case .create(let request):
            return request
        case .update(_, let request):
            return request
        case .createComment(_, let request):
            return request
        case .updateComment(_, _, let request):
            return request
        case .like(_, let request):
            return request
        case .uploadFiles, .geolocation, .search, .detail, .delete, .deleteComment,
             .userPosts, .likedPosts:
            return nil
        }
    }

    var multipartFormData: MultipartFormData? {
        switch self {
        case .uploadFiles(let request):
            return MultipartFormData(parts: request.files.map { .file(name: "files", file: $0) })
        case .create, .geolocation, .search, .detail, .update, .delete, .createComment,
             .updateComment, .deleteComment, .like, .userPosts, .likedPosts:
            return nil
        }
    }

    var requiresAuthentication: Bool {
        true
    }
}
