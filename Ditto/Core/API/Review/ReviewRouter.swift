//
//  ReviewRouter.swift
//  Ditto
//
//  Created by Codex on 4/25/26.
//

import Foundation

enum ReviewRouter: APIRouter {
    case uploadFiles(activityId: String, request: ReviewFileUploadRequestDTO)
    case create(activityId: String, request: ReviewCreateRequestDTO)
    case list(ReviewListQuery)
    case detail(activityId: String, reviewId: String)
    case update(activityId: String, reviewId: String, request: ReviewUpdateRequestDTO)
    case delete(activityId: String, reviewId: String)
    case ratingSummary(activityId: String)
    case reviewsByUser(UserReviewListQuery)
}

extension ReviewRouter {
    var path: String {
        switch self {
        case .uploadFiles(let activityId, _):
            return "v1/activities/\(activityId)/reviews/files"
        case .create(let activityId, _):
            return "v1/activities/\(activityId)/reviews"
        case .list(let query):
            return "v1/activities/\(query.activityId)/reviews"
        case .detail(let activityId, let reviewId), .update(let activityId, let reviewId, _),
             .delete(let activityId, let reviewId):
            return "v1/activities/\(activityId)/reviews/\(reviewId)"
        case .ratingSummary(let activityId):
            return "v1/activities/\(activityId)/reviews/reviews-ratings"
        case .reviewsByUser(let query):
            return "v1/activities/reviews/users/\(query.userId)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list, .detail, .ratingSummary, .reviewsByUser:
            return .get
        case .update:
            return .put
        case .delete:
            return .delete
        case .uploadFiles, .create:
            return .post
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .list(let query):
            // nil 필터를 빈 키로 보내면 서버가 빈 문자열 매칭으로 0건을 반환할 수 있어
            // 값이 있는 항목만 query에 추가한다.
            return [
                query.next.map { URLQueryItem(name: "next", value: $0) },
                query.limit.map { URLQueryItem(name: "limit", value: String($0)) },
                query.orderBy.map { URLQueryItem(name: "order_by", value: $0.rawValue) }
            ]
            .compactMap { $0 }
        case .reviewsByUser(let query):
            return [
                query.country.map { URLQueryItem(name: "country", value: $0) },
                query.category.map { URLQueryItem(name: "category", value: $0) },
                query.next.map { URLQueryItem(name: "next", value: $0) },
                query.limit.map { URLQueryItem(name: "limit", value: String($0)) }
            ]
            .compactMap { $0 }
        case .uploadFiles, .create, .detail, .update, .delete, .ratingSummary:
            return []
        }
    }

    var body: Encodable? {
        switch self {
        case .create(_, let request):
            return request
        case .update(_, _, let request):
            return request
        case .uploadFiles, .list, .detail, .delete, .ratingSummary, .reviewsByUser:
            return nil
        }
    }

    var multipartFormData: MultipartFormData? {
        switch self {
        case .uploadFiles(_, let request):
            return MultipartFormData(parts: request.files.map { .file(name: "files", file: $0) })
        case .create, .list, .detail, .update, .delete, .ratingSummary, .reviewsByUser:
            return nil
        }
    }

    var requiresAuthentication: Bool {
        true
    }
}
