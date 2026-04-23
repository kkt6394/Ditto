//
//  UserRouter.swift
//  Ditto
//
//  Created by 김기태 on 4/23/26.
//

enum UserRouter: APIRouter {
    case join(
        email: String,
        password: String,
        nick: String,
        phoneNum: String? = nil,
        introduction: String? = nil,
        deviceToken: String? = nil
    )
    case login(email: String, password: String, deviceToken: String? = nil)
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
        case .join(let email, let password, let nick, let phoneNum, let introduction, let deviceToken):
            return JoinRequest(
                email: email,
                password: password,
                nick: nick,
                phoneNum: phoneNum,
                introduction: introduction,
                deviceToken: deviceToken
            )
        case .login(let email, let password, let deviceToken):
            return LoginRequest(email: email, password: password, deviceToken: deviceToken)
        }
    }
}

struct JoinResponse: Decodable, Equatable {
    let userID: String
    let email: String
    let nick: String
    let accessToken: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case email
        case nick
        case accessToken
        case refreshToken
    }
}

struct LoginResponse: Decodable, Equatable {
    let userID: String
    let email: String
    let nick: String
    let accessToken: String
    let refreshToken: String
    let profileImage: String?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case email
        case nick
        case accessToken
        case refreshToken
        case profileImage
    }
}

private extension UserRouter {
    struct JoinRequest: Encodable {
        let email: String
        let password: String
        let nick: String
        let phoneNum: String?
        let introduction: String?
        let deviceToken: String?
    }

    struct LoginRequest: Encodable {
        let email: String
        let password: String
        let deviceToken: String?
    }
}
