//
//  SignUpViewModelTests.swift
//  DittoTests
//
//  Created by 김기태 on 4/23/26.
//

import Foundation
import Testing
@testable import Ditto

@MainActor
struct SignUpViewModelTests {
    @Test func emptyNickReturnsValidationError() {
        // 네트워크와 무관한 입력 검증은 StubNetworkManager로 외부 의존성을 제거하고 확인한다.
        let viewModel = SignUpViewModel(networkManager: StubNetworkManager())

        viewModel.email = "ditto@example.com"
        viewModel.password = "password123"
        viewModel.nick = " "

        #expect(viewModel.validate() == .emptyNick)
    }

    @Test func validInputPassesValidation() {
        let viewModel = SignUpViewModel(networkManager: StubNetworkManager())

        viewModel.email = "ditto@example.com"
        viewModel.password = "password123"
        viewModel.nick = "di"

        #expect(viewModel.validate() == nil)
    }

    @Test func validInputSendsJoinRequestWithoutDeviceToken() async throws {
        let networkManager = StubNetworkManager()
        let authManager = StubSignUpAuthManager()
        let viewModel = SignUpViewModel(networkManager: networkManager, authManager: authManager)

        // 앞뒤 공백과 빈 optional 입력이 request body로 변환될 때 어떻게 정리되는지 검증한다.
        viewModel.email = " ditto@example.com "
        viewModel.password = "password123"
        viewModel.nick = " ditto "
        viewModel.phoneNum = " "
        viewModel.introduction = "activity lover"

        await viewModel.submitSignUp()

        #expect(viewModel.message == .success("ditto님, 회원가입이 완료됐습니다."))
        #expect(authManager.savedTokens == JoinResponse.dummy.tokens)

        let router = try #require(networkManager.requestedRouter as? AuthRouter)

        if case .join(let request) = router {
            // deviceToken은 필수값이 아니므로 화면에서 입력하지 않으면 nil로 유지되어야 한다.
            #expect(request.email == "ditto@example.com")
            #expect(request.password == "password123")
            #expect(request.nick == "ditto")
            #expect(request.phoneNum == nil)
            #expect(request.introduction == "activity lover")
            #expect(request.deviceToken == nil)
        } else {
            #expect(Bool(false))
        }
    }

    @Test func serverMessageIsShownOnFailure() async {
        let networkManager = StubNetworkManager(
            result: .failure(NetworkError.statusCode(409, message: "이미 가입된 이메일입니다.", data: Data()))
        )
        let viewModel = SignUpViewModel(networkManager: networkManager)

        viewModel.email = "ditto@example.com"
        viewModel.password = "password123"
        viewModel.nick = "ditto"

        await viewModel.submitSignUp()

        #expect(viewModel.message == .error("이미 가입된 이메일입니다."))
    }
}

@MainActor
private final class StubSignUpAuthManager: AuthManaging {
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
private final class StubNetworkManager: NetworkManaging {
    // 마지막으로 받은 router를 보관해 ViewModel이 어떤 endpoint를 호출했는지 테스트한다.
    private(set) var requestedRouter: APIRouter?
    private let result: Result<JoinResponse, Error>

    init(result: Result<JoinResponse, Error> = .success(.dummy)) {
        self.result = result
    }

    func request<T: Decodable>(_ router: APIRouter) async throws -> T {
        requestedRouter = router

        switch result {
        case .success(let response):
            // NetworkManaging은 제네릭 응답을 반환하므로 테스트 더블에서도 타입이 맞는지 확인한다.
            guard let typedResponse = response as? T else {
                throw StubNetworkError.typeMismatch
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

private extension JoinResponse {
    static let dummy = JoinResponse(
        userID: "user-id",
        email: "ditto@example.com",
        nick: "ditto",
        accessToken: "access-token",
        refreshToken: "refresh-token"
    )
}

private enum StubNetworkError: Error {
    case typeMismatch
}
