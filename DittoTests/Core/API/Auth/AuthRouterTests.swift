//
//  AuthRouterTests.swift
//  DittoTests
//
//  Created by 김기태 on 4/23/26.
//

import Foundation
import Testing
@testable import Ditto

struct AuthRouterTests {
    @Test func joinResponseDecodesUserIdFromSnakeCasePayload() throws {
        // NetworkManager 기본 decoder는 snake_case를 camelCase로 바꾸므로 모델도 userId를 사용해야 한다.
        let data = Data(
            """
            {
              "user_id": "user-id",
              "email": "ditto@example.com",
              "nick": "ditto",
              "accessToken": "access-token",
              "refreshToken": "refresh-token"
            }
            """.utf8
        )
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let response = try decoder.decode(JoinResponse.self, from: data)

        #expect(response.userId == "user-id")
        #expect(response.tokens == AuthTokens(accessToken: "access-token", refreshToken: "refresh-token"))
    }

    @Test func loginResponseDecodesUserIdFromSnakeCasePayload() throws {
        let data = Data(
            """
            {
              "user_id": "user-id",
              "email": "ditto@example.com",
              "nick": "ditto",
              "accessToken": "access-token",
              "refreshToken": "refresh-token",
              "profileImage": null
            }
            """.utf8
        )
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let response = try decoder.decode(LoginResponse.self, from: data)

        #expect(response.userId == "user-id")
        #expect(response.profileImage == nil)
    }

    @Test func joinRouterUsesPostMethodAndJoinPath() {
        // Router 테스트는 실제 통신이 아니라 endpoint 정의가 맞는지만 빠르게 검증한다.
        let request = JoinRequest(
            email: "ditto@example.com",
            password: "password123",
            nick: "ditto"
        )
        let router = AuthRouter.join(request)

        #expect(router.method == .post)
        #expect(router.path == "v1/users/join")
    }

    @Test func loginRouterUsesPostMethodAndLoginPath() {
        // 로그인도 회원가입과 같은 AuthRouter에서 관리해 endpoint 정의 위치를 통일한다.
        let request = LoginRequest(email: "ditto@example.com", password: "password123")
        let router = AuthRouter.login(request)

        #expect(router.method == .post)
        #expect(router.path == "v1/users/login")
    }

    @Test func kakaoLoginRouterUsesPostMethodAndKakaoLoginPath() {
        let request = KakaoLoginRequest(oauthToken: "kakao-oauth-token", deviceToken: nil)
        let router = AuthRouter.loginKakao(request)

        #expect(router.method == .post)
        #expect(router.path == "v1/users/login/kakao")
        #expect(!router.requiresAuthentication)
    }

    @Test func appleLoginRouterUsesPostMethodAndAppleLoginPath() {
        let request = AppleLoginRequest(idToken: "apple-id-token", deviceToken: nil)
        let router = AuthRouter.loginApple(request)

        #expect(router.method == .post)
        #expect(router.path == "v1/users/login/apple")
        #expect(!router.requiresAuthentication)
    }

    @Test func loginBodyOmitsNilDeviceToken() throws {
        // optional body 값이 nil일 때 JSON에 포함되지 않는지 확인한다.
        let request = LoginRequest(email: "ditto@example.com", password: "password123")
        let router = AuthRouter.login(request)
        let body = try #require(router.body)
        let data = try JSONEncoder().encode(AnyEncodable(body))
        let dictionary = try #require(try JSONSerialization.jsonObject(with: data) as? [String: String])

        #expect(dictionary["email"] == "ditto@example.com")
        #expect(dictionary["password"] == "password123")
        #expect(dictionary["deviceToken"] == nil)
    }

    @Test func refreshRouterUsesGetPathAndRefreshHeader() {
        let tokens = AuthTokens(accessToken: "access-token", refreshToken: "refresh-token")
        let router = AuthRouter.refresh(tokens)

        #expect(router.method == .get)
        #expect(router.path == "v1/auth/refresh")
        #expect(router.requiresAuthentication)
        #expect(!router.allowsTokenRefreshRetry)
        #expect(router.headers["RefreshToken"] == "refresh-token")
    }
}

// 테스트에서도 router.body의 Encodable 값을 JSON으로 확인하기 위해 사용하는 type eraser다.
private struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void

    init(_ value: Encodable) {
        encodeValue = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeValue(encoder)
    }
}
