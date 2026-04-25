//
//  AuthRouter.swift
//  Ditto
//
//  Created by 김기태 on 4/23/26.
//

// Auth 관련 API endpoint를 정의한다.
// Core/API는 API 명세 타입을 모으고, Core/Network는 실제 통신 인프라만 담당한다.
enum AuthRouter: APIRouter {
    case validateEmail(EmailValidationRequest)
    case join(JoinRequest)
    case login(LoginRequest)
    case loginKakao(KakaoLoginRequest)
    case loginApple(AppleLoginRequest)
    case refresh(AuthTokens)
    case logout
    case updateDeviceToken(DeviceTokenRequest)
}

extension AuthRouter {
    var path: String {
        switch self {
        case .validateEmail:
            return "v1/users/validation/email"
        case .join:
            // API 문서 기준 회원가입 endpoint는 users 복수형을 사용한다.
            return "v1/users/join"
        case .login:
            return "v1/users/login"
        case .loginKakao:
            return "v1/users/login/kakao"
        case .loginApple:
            return "v1/users/login/apple"
        case .refresh:
            return "v1/auth/refresh"
        case .logout:
            return "v1/users/logout"
        case .updateDeviceToken:
            return "v1/users/deviceToken"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .refresh:
            return .get
        case .updateDeviceToken:
            return .put
        case .validateEmail, .join, .login, .loginKakao, .loginApple, .logout:
            return .post
        }
    }

    var body: Encodable? {
        // Router는 어떤 DTO를 보낼지만 결정하고, 실제 JSON 인코딩은 NetworkManager가 수행한다.
        switch self {
        case .validateEmail(let request):
            return request
        case .join(let request):
            return request
        case .login(let request):
            return request
        case .loginKakao(let request):
            return request
        case .loginApple(let request):
            return request
        case .updateDeviceToken(let request):
            return request
        case .refresh, .logout:
            return nil
        }
    }

    var headers: [String: String] {
        switch self {
        case .refresh(let tokens):
            return ["RefreshToken": tokens.refreshToken]
        case .validateEmail, .join, .login, .loginKakao, .loginApple, .logout, .updateDeviceToken:
            return [:]
        }
    }

    var requiresAuthentication: Bool {
        switch self {
        case .refresh, .logout, .updateDeviceToken:
            return true
        case .validateEmail, .join, .login, .loginKakao, .loginApple:
            return false
        }
    }

    var allowsTokenRefreshRetry: Bool {
        switch self {
        case .refresh:
            return false
        default:
            return requiresAuthentication
        }
    }
}
