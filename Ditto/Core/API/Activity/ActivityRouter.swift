//
//  ActivityRouter.swift
//  Ditto
//
//  Created by Codex on 4/25/26.
//

import Foundation

enum ActivityRouter: APIRouter {
    case uploadFiles(ActivityFileUploadRequestDTO)
    case create(ActivityCreateRequestDTO)
    case list(ActivityListQuery)
    case detail(activityId: String)
    case update(activityId: String, request: ActivityUpdateRequestDTO)
    case keep(activityId: String, request: ActivityKeepRequestDTO)
    case new(ActivityPreviewQuery)
    case search(title: String)
    case myKeeps(ActivityKeepListQuery)
}

extension ActivityRouter {
    var path: String {
        switch self {
        case .uploadFiles:
            return "v1/activities/files"
        case .create, .list:
            return "v1/activities"
        case .detail(let activityId):
            return "v1/activities/\(activityId)"
        case .update(let activityId, _):
            return "v1/activities/\(activityId)"
        case .keep(let activityId, _):
            return "v1/activities/\(activityId)/keep"
        case .new:
            return "v1/activities/new"
        case .search:
            return "v1/activities/search"
        case .myKeeps:
            return "v1/activities/keeps/me"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .list, .detail, .new, .search, .myKeeps:
            return .get
        case .update:
            return .put
        case .uploadFiles, .create, .keep:
            return .post
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .list(let query):
            return Self.makeQueryItems(
                country: query.country,
                category: query.category,
                limit: query.limit,
                next: query.next
            )
        case .new(let query):
            return Self.makeQueryItems(country: query.country, category: query.category)
        case .search(let title):
            return [URLQueryItem(name: "title", value: title)]
        case .myKeeps(let query):
            return Self.makeQueryItems(
                country: query.country,
                category: query.category,
                limit: query.limit,
                next: query.next
            )
        case .uploadFiles, .create, .detail, .update, .keep:
            return []
        }
    }

    var body: Encodable? {
        switch self {
        case .create(let request):
            return request
        case .update(_, let request):
            return request
        case .keep(_, let request):
            return request
        case .uploadFiles, .list, .detail, .new, .search, .myKeeps:
            return nil
        }
    }

    var multipartFormData: MultipartFormData? {
        switch self {
        case .uploadFiles(let request):
            return MultipartFormData(parts: request.files.map { .file(name: "files", file: $0) })
        case .create, .list, .detail, .update, .keep, .new, .search, .myKeeps:
            return nil
        }
    }

    var requiresAuthentication: Bool {
        true
    }
}

private extension ActivityRouter {
    static func makeQueryItems(
        country: String?,
        category: String?,
        limit: Int? = nil,
        next: String? = nil
    ) -> [URLQueryItem] {
        [
            URLQueryItem(name: "country", value: country),
            URLQueryItem(name: "category", value: category),
            limit.map { URLQueryItem(name: "limit", value: String($0)) },
            URLQueryItem(name: "next", value: next)
        ]
        .compactMap { $0 }
    }
}
