//
//  UserRouter.swift
//  Ditto
//
//  Created by 김기태 on 4/23/26.
//

enum UserRouter: APIRouter {
    case join(JoinRequest)
    case login(LoginRequest)
}

extension UserRouter {
    var path: String {
        switch self {
        case .join:
            return "v1/user/join"
        case .login:
            return "v1/users/login"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .join, .login:
            return .post
        }
    }

    var body: Encodable? {
        switch self {
        case .join(let request):
            return request
        case .login(let request):
            return request
        }
    }
}
