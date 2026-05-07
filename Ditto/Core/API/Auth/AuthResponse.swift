//
//  AuthResponse.swift
//  Ditto
//
//  Created by 김기태 on 4/23/26.
//

// 회원가입 성공 시 서버가 내려주는 사용자 인증 정보다.
struct JoinResponse: Decodable, Equatable {
    let userId: String
    let email: String
    let nick: String
    let accessToken: String
    let refreshToken: String
}

extension JoinResponse {
    var tokens: AuthTokens {
        AuthTokens(accessToken: accessToken, refreshToken: refreshToken)
    }
}

// 이메일 로그인 성공 응답이다. profileImage는 없을 수도 있으므로 Optional로 둔다.
struct LoginResponse: Decodable, Equatable {
    let userId: String
    let email: String
    let nick: String
    let accessToken: String
    let refreshToken: String
    let profileImage: String?
}

extension LoginResponse {
    var tokens: AuthTokens {
        AuthTokens(accessToken: accessToken, refreshToken: refreshToken)
    }
}

// accessToken 만료 후 refresh API가 내려주는 새 인증 토큰 묶음이다.
struct RefreshTokenResponse: Decodable, Equatable {
    let accessToken: String
    let refreshToken: String
}

extension RefreshTokenResponse {
    var tokens: AuthTokens {
        AuthTokens(accessToken: accessToken, refreshToken: refreshToken)
    }
}

// 이메일 중복검사 API 응답이다. 200/400/409 모두 message 한 필드만 내려온다.
struct EmailValidationResponse: Decodable, Equatable {
    let message: String
}
