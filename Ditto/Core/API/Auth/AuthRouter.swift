//
//  AuthRouter.swift
//  Ditto
//
//  Created by 김기태 on 4/23/26.
//

// Auth 관련 API endpoint를 정의한다.
// Core/API는 API 명세 타입을 모으고, Core/Network는 실제 통신 인프라만 담당한다.
enum AuthRouter: APIRouter {
    case join(JoinRequest)
    case login(LoginRequest)
    case refresh(AuthTokens)
}

extension AuthRouter {
    var path: String {
        switch self {
        case .join:
            // API 문서 기준 회원가입 endpoint는 users 복수형을 사용한다.
            return "v1/users/join"
        case .login:
            return "v1/users/login"
        case .refresh:
            return "v1/auth/refresh"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .refresh:
            return .get
        case .join, .login:
            return .post
        }
    }

    var body: Encodable? {
        // Router는 어떤 DTO를 보낼지만 결정하고, 실제 JSON 인코딩은 NetworkManager가 수행한다.
        switch self {
        case .join(let request):
            return request
        case .login(let request):
            return request
        case .refresh:
            return nil
        }
    }

    var headers: [String: String] {
        switch self {
        case .refresh(let tokens):
            return ["RefreshToken": tokens.refreshToken]
        case .join, .login:
            return [:]
        }
    }

    var requiresAuthentication: Bool {
        switch self {
        case .refresh:
            return true
        case .join, .login:
            return false
        }
    }

    var allowsTokenRefreshRetry: Bool {
        switch self {
        case .refresh:
            return false
        case .join, .login:
            return false
        }
    }
}
