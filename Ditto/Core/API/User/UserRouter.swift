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
    case withdraw
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
        case .withdraw:
            return "v1/users/withdraw"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .myProfile, .search:
            return .get
        case .updateProfile:
            return .put
        case .uploadProfileImage, .withdraw:
            return .post
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .search(let nick):
            return [URLQueryItem(name: "nick", value: nick)]
        case .myProfile, .updateProfile, .uploadProfileImage, .withdraw:
            return []
        }
    }

    var body: Encodable? {
        switch self {
        case .updateProfile(let request):
            return request
        case .myProfile, .uploadProfileImage, .search, .withdraw:
            return nil
        }
    }

    var multipartFormData: MultipartFormData? {
        switch self {
        case .uploadProfileImage(let request):
            return MultipartFormData(parts: [.file(name: "profile", file: request.profile)])
        case .myProfile, .updateProfile, .search, .withdraw:
            return nil
        }
    }

    var requiresAuthentication: Bool {
        true
    }
}
