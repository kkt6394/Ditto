//
//  UserRouter.swift
//  Ditto
//
//  Created by Codex on 4/25/26.
//

import Foundation

enum UserRouter: APIRouter {
    case myProfile
    case updateProfile(ProfileRequestDTO)
    case uploadProfileImage(ProfileImageUploadRequestDTO)
    case search(nick: String)
}

extension UserRouter {
    var path: String {
        switch self {
        case .myProfile, .updateProfile:
            return "v1/users/me/profile"
        case .uploadProfileImage:
            return "v1/users/profile/image"
        case .search:
            return "v1/users/search"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .myProfile, .search:
            return .get
        case .updateProfile:
            return .put
        case .uploadProfileImage:
            return .post
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .search(let nick):
            return [URLQueryItem(name: "nick", value: nick)]
        case .myProfile, .updateProfile, .uploadProfileImage:
            return []
        }
    }

    var body: Encodable? {
        switch self {
        case .updateProfile(let request):
            return request
        case .myProfile, .uploadProfileImage, .search:
            return nil
        }
    }

    var multipartFormData: MultipartFormData? {
        switch self {
        case .uploadProfileImage(let request):
            return MultipartFormData(parts: [.file(name: "profile", file: request.profile)])
        case .myProfile, .updateProfile, .search:
            return nil
        }
    }

    var requiresAuthentication: Bool {
        true
    }
}
