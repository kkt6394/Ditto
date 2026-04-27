//
//  LoginViewModelTests.swift
//  DittoTests
//
//  Created by 김기태 on 4/23/26.
//

import Foundation
import Testing
@testable import Ditto

@MainActor
struct LoginViewModelTests {
    @Test func emptyEmailReturnsValidationError() {
        // 공백만 입력한 이메일도 빈 이메일로 처리되는지 확인한다.
        let viewModel = LoginViewModel(networkManager: StubLoginNetworkManager())

        viewModel.email = " "
        viewModel.password = "password123"

        #expect(viewModel.validate() == .emptyEmail)
    }

    @Test func invalidEmailReturnsValidationError() {
        let viewModel = LoginViewModel(networkManager: StubLoginNetworkManager())

        viewModel.email = "ditto"
        viewModel.password = "password123"

        #expect(viewModel.validate() == .invalidEmail)
    }

    @Test func shortPasswordReturnsValidationError() {
        let viewModel = LoginViewModel(networkManager: StubLoginNetworkManager())

        viewModel.email = "ditto@example.com"
        viewModel.password = "1234567"

        #expect(viewModel.validate() == .shortPassword(minLength: 8))
    }

    @Test func validInputPassesValidation() {
        let viewModel = LoginViewModel(networkManager: StubLoginNetworkManager())

        viewModel.email = "ditto@example.com"
        viewModel.password = "password123"

        #expect(viewModel.validate() == nil)
    }

    @Test func socialLoginSelectionShowsPreparedMessage() {
        // 아직 API가 연결되지 않은 액션은 사용자에게 준비 중 메시지를 보여준다.
        let viewModel = LoginViewModel(networkManager: StubLoginNetworkManager())

        viewModel.selectSocialLogin(provider: .apple)

        #expect(viewModel.message == .info("Apple 로그인은 연결 준비 중입니다."))
    }

    @Test func validInputSendsLoginRequestWithoutDeviceToken() async throws {
        let networkManager = StubLoginNetworkManager()
        let authManager = StubLoginAuthManager()
        let viewModel = LoginViewModel(networkManager: networkManager, authManager: authManager)

        viewModel.email = " ditto@example.com "
        viewModel.password = "password123"

        await viewModel.submitLogin()

        #expect(viewModel.message == .success("ditto님, 다시 오신 걸 환영해요."))
        #expect(authManager.savedTokens == LoginResponse.dummy.tokens)

        let router = try #require(networkManager.requestedRouter as? AuthRouter)

        if case .login(let request) = router {
            #expect(request.email == "ditto@example.com")
            #expect(request.password == "password123")
            #expect(request.deviceToken == nil)
        } else {
            #expect(Bool(false))
        }
    }

    @Test func serverMessageIsShownOnFailure() async {
        let networkManager = StubLoginNetworkManager(
            result: .failure(NetworkError.statusCode(401, message: "이메일 또는 비밀번호를 확인해 주세요.", data: Data()))
        )
        let viewModel = LoginViewModel(networkManager: networkManager)

        viewModel.email = "ditto@example.com"
        viewModel.password = "password123"

        await viewModel.submitLogin()

        #expect(viewModel.message == .error("이메일 또는 비밀번호를 확인해 주세요."))
    }

    @Test func kakaoLoginSendsOAuthTokenToKakaoLoginAPI() async throws {
        let networkManager = StubLoginNetworkManager()
        let authManager = StubLoginAuthManager()
        let viewModel = LoginViewModel(
            networkManager: networkManager,
            authManager: authManager,
            kakaoLoginService: StubKakaoLoginService(oauthToken: "kakao-oauth-token")
        )

        await viewModel.submitKakaoLogin()

        #expect(viewModel.message == .success("ditto님, 다시 오신 걸 환영해요."))
        #expect(authManager.savedTokens == LoginResponse.dummy.tokens)

        let router = try #require(networkManager.requestedRouter as? AuthRouter)

        if case .loginKakao(let request) = router {
            #expect(request.oauthToken == "kakao-oauth-token")
            #expect(request.deviceToken == nil)
        } else {
            #expect(Bool(false))
        }
    }

    @Test func appleLoginSendsIdTokenToAppleLoginAPI() async throws {
        let networkManager = StubLoginNetworkManager()
        let authManager = StubLoginAuthManager()
        let viewModel = LoginViewModel(networkManager: networkManager, authManager: authManager)

        await viewModel.submitAppleLogin(idToken: "apple-id-token")

        #expect(viewModel.message == .success("ditto님, 다시 오신 걸 환영해요."))
        #expect(authManager.savedTokens == LoginResponse.dummy.tokens)

        let router = try #require(networkManager.requestedRouter as? AuthRouter)

        if case .loginApple(let request) = router {
            #expect(request.idToken == "apple-id-token")
            #expect(request.deviceToken == nil)
        } else {
            #expect(Bool(false))
        }
    }
}

@MainActor
private final class StubLoginAuthManager: AuthManaging {
    private(set) var tokens: AuthTokens?

    var isAuthenticated: Bool {
        tokens != nil
    }

    var savedTokens: AuthTokens? {
        tokens
    }

    func authenticate(with tokens: AuthTokens) throws {
        self.tokens = tokens
    }

    func signOut() throws {
        tokens = nil
    }
}

@MainActor
private final class StubLoginNetworkManager: NetworkManaging {
    private(set) var requestedRouter: APIRouter?
    private let result: Result<LoginResponse, Error>

    init(result: Result<LoginResponse, Error> = .success(.dummy)) {
        self.result = result
    }

    func request<T: Decodable>(_ router: APIRouter) async throws -> T {
        requestedRouter = router

        switch result {
        case .success(let response):
            guard let typedResponse = response as? T else {
                throw StubLoginNetworkError.typeMismatch
            }
            return typedResponse
        case .failure(let error):
            throw error
        }
    }

    func send(_ router: APIRouter) async throws {
        requestedRouter = router
    }
}

@MainActor
private struct StubKakaoLoginService: KakaoLoginServicing {
    let oauthToken: String

    func login() async throws -> String {
        oauthToken
    }
}

private extension LoginResponse {
    static let dummy = LoginResponse(
        userId: "user-id",
        email: "ditto@example.com",
        nick: "ditto",
        accessToken: "access-token",
        refreshToken: "refresh-token",
        profileImage: nil
    )
}

private enum StubLoginNetworkError: Error {
    case typeMismatch
}
