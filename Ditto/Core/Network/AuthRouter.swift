//
//  AuthRouter.swift
//  Ditto
//
//  Created by 김기태 on 4/23/26.
//

import Foundation

enum AuthRouter: APIRouter {
    case login(email: String, password: String)
}

extension AuthRouter {
    var path: String {
        switch self {
        case .login:
            return "v1/users/login"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .login:
            return .post
        }
    }

    var body: Encodable? {
        switch self {
        case .login(let email, let password):
            return LoginRequest(email: email, password: password)
        }
    }
}

private extension AuthRouter {
    struct LoginRequest: Encodable {
        let email: String
        let password: String
    }
}
