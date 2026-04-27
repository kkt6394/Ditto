//
//  LoginViewModel.swift
//  Ditto
//
//  Created by 김기태 on 4/23/26.
//

import Foundation
import Observation

// @Observable을 붙이면 SwiftUI View가 이 객체의 저장 프로퍼티 변화를 추적한다.
@MainActor
@Observable
final class LoginViewModel {
    var email = ""
    var password = ""
    private(set) var isSubmitting = false
    private(set) var message: LoginMessage?

    let socialProviders = SocialLoginProvider.allCases
    private let networkManagerProvider: @MainActor () throws -> any NetworkManaging
    private let authManager: any AuthManaging
    private let kakaoLoginService: any KakaoLoginServicing

    convenience init() {
        let authManager = AuthManager()

        self.init(
            networkManagerProvider: {
                // 기본 실행 경로에서는 앱 설정값을 읽어 실제 NetworkManager를 만든다.
                NetworkManager(configuration: try AppConfiguration(), authManager: authManager)
            },
            authManager: authManager,
            kakaoLoginService: KakaoLoginService()
        )
    }

    convenience init(authManager: any AuthManaging) {
        self.init(
            networkManagerProvider: {
                // 기본 실행 경로에서는 앱 설정값을 읽어 실제 NetworkManager를 만든다.
                NetworkManager(configuration: try AppConfiguration(), authManager: authManager)
            },
            authManager: authManager,
            kakaoLoginService: KakaoLoginService()
        )
    }

    init(
        networkManagerProvider: @escaping @MainActor () throws -> any NetworkManaging,
        authManager: any AuthManaging,
        kakaoLoginService: any KakaoLoginServicing
    ) {
        self.networkManagerProvider = networkManagerProvider
        self.authManager = authManager
        self.kakaoLoginService = kakaoLoginService
    }

    convenience init(networkManager: any NetworkManaging) {
        self.init(networkManager: networkManager, authManager: AuthManager())
    }

    init(networkManager: any NetworkManaging, authManager: any AuthManaging) {
        // 테스트에서는 StubNetworkManager를 주입해 네트워크 결과를 고정한다.
        networkManagerProvider = {
            networkManager
        }
        self.authManager = authManager
        kakaoLoginService = KakaoLoginService()
    }

    init(
        networkManager: any NetworkManaging,
        authManager: any AuthManaging,
        kakaoLoginService: any KakaoLoginServicing
    ) {
        // 테스트에서는 StubNetworkManager와 StubKakaoLoginService를 주입해 외부 인증 흐름을 고정한다.
        networkManagerProvider = {
            networkManager
        }
        self.authManager = authManager
        self.kakaoLoginService = kakaoLoginService
    }

    var isLoginButtonEnabled: Bool {
        // 버튼 활성화 로직을 ViewModel에 두면 View 테스트 없이도 입력 정책을 검증할 수 있다.
        !trimmedEmail.isEmpty && !password.isEmpty && !isSubmitting
    }

    @discardableResult
    func submitLogin() async -> Bool {
        message = nil

        if let error = validate() {
            message = .error(error.message)
            return false
        }

        isSubmitting = true
        defer {
            // 성공/실패와 무관하게 버튼 로딩 상태를 항상 원복한다.
            isSubmitting = false
        }

        do {
            let networkManager = try networkManagerProvider()
            let response: LoginResponse = try await networkManager.request(AuthRouter.login(makeLoginRequest()))
            try authManager.authenticate(with: response.tokens)
            message = .success("\(response.nick)님, 다시 오신 걸 환영해요.")
            return true
        } catch {
            message = .error(Self.makeErrorMessage(from: error))
            return false
        }
    }

    func selectSocialLogin(provider: SocialLoginProvider) {
        message = .info("\(provider.title) 로그인은 연결 준비 중입니다.")
    }

    @discardableResult
    func submitKakaoLogin() async -> Bool {
        message = nil
        isSubmitting = true
        defer {
            isSubmitting = false
        }

        do {
            let oauthToken = try await kakaoLoginService.login()
            let networkManager = try networkManagerProvider()
            let request = KakaoLoginRequest(oauthToken: oauthToken, deviceToken: nil)
            let response: LoginResponse = try await networkManager.request(AuthRouter.loginKakao(request))
            try authManager.authenticate(with: response.tokens)
            message = .success("\(response.nick)님, 다시 오신 걸 환영해요.")
            return true
        } catch {
            message = .error(Self.makeErrorMessage(from: error))
            return false
        }
    }

    @discardableResult
    func submitAppleLogin(idToken: String) async -> Bool {
        message = nil
        isSubmitting = true
        defer {
            isSubmitting = false
        }

        do {
            let networkManager = try networkManagerProvider()
            let request = AppleLoginRequest(idToken: idToken, deviceToken: nil)
            let response: LoginResponse = try await networkManager.request(AuthRouter.loginApple(request))
            try authManager.authenticate(with: response.tokens)
            message = .success("\(response.nick)님, 다시 오신 걸 환영해요.")
            return true
        } catch {
            message = .error(Self.makeErrorMessage(from: error))
            return false
        }
    }

    func handleAppleLoginFailure(message: String) {
        self.message = .error(message)
    }

    func selectForgotPassword() {
        message = .info("비밀번호 찾기 화면은 준비 중입니다.")
    }

    func selectSignUp() {
        message = .info("회원가입 화면은 준비 중입니다.")
    }

    func validate() -> LoginValidationError? {
        // 검증은 가장 먼저 만난 오류를 반환해 사용자가 한 번에 하나씩 수정할 수 있게 한다.
        if trimmedEmail.isEmpty {
            return .emptyEmail
        }

        if !trimmedEmail.contains("@") {
            return .invalidEmail
        }

        if password.isEmpty {
            return .emptyPassword
        }

        if password.count < LoginRule.minimumPasswordLength {
            return .shortPassword(minLength: LoginRule.minimumPasswordLength)
        }

        return nil
    }

    private var trimmedEmail: String {
        // 공백만 입력한 이메일은 빈 값과 동일하게 처리한다.
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func makeLoginRequest() -> LoginRequest {
        // 화면에서 받지 않는 deviceToken은 nil로 두고, 이메일 공백만 정리해 요청한다.
        LoginRequest(email: trimmedEmail, password: password)
    }

    static func makeErrorMessage(from error: Error) -> String {
        // ViewModel은 네트워크 계층 오류를 사용자 메시지로 번역한다.
        switch error {
        case let error as NetworkError:
            return makeNetworkErrorMessage(from: error)
        case AuthManagerError.tokenSaveFailed:
            return "인증 정보를 저장할 수 없습니다."
        case KakaoLoginServiceError.missingNativeAppKey:
            return "카카오 앱 키를 확인해 주세요."
        case KakaoLoginServiceError.missingOAuthToken:
            return "카카오 인증 정보를 확인할 수 없습니다."
        case AppConfigurationError.missingValue, AppConfigurationError.invalidURL:
            return "API 설정값을 확인해 주세요."
        default:
            return "로그인 요청에 실패했습니다."
        }
    }

    static func makeNetworkErrorMessage(from error: NetworkError) -> String {
        switch error {
        case .invalidURL:
            return "요청 주소가 올바르지 않습니다."
        case .invalidResponse:
            return "서버 응답을 확인할 수 없습니다."
        case .missingAuthenticationToken:
            return "로그인이 필요합니다."
        case .statusCode(_, let message, _):
            return message ?? "로그인 요청에 실패했습니다."
        case .encodingFailed:
            return "요청 데이터를 만들 수 없습니다."
        case .decodingFailed:
            return "로그인 처리 중 문제가 발생했습니다. 잠시 후 다시 시도해 주세요."
        case .requestFailed:
            return "네트워크 연결을 확인해 주세요."
        }
    }
}

enum LoginRule {
    // 화면 문구와 검증 기준이 어긋나지 않도록 숫자 정책을 한 곳에 둔다.
    static let minimumPasswordLength = 8
}

enum LoginValidationError: Equatable {
    // Equatable을 채택해 테스트에서 검증 실패 타입을 직접 비교할 수 있다.
    case emptyEmail
    case invalidEmail
    case emptyPassword
    case shortPassword(minLength: Int)

    var message: String {
        switch self {
        case .emptyEmail:
            return "이메일을 입력해 주세요."
        case .invalidEmail:
            return "올바른 이메일 형식으로 입력해 주세요."
        case .emptyPassword:
            return "비밀번호를 입력해 주세요."
        case .shortPassword(let minLength):
            return "비밀번호는 \(minLength)자 이상 입력해 주세요."
        }
    }
}

enum LoginMessage: Equatable {
    // 메시지 타입을 나누면 View가 안내/오류의 시각 표현을 분리할 수 있다.
    case success(String)
    case info(String)
    case error(String)

    var text: String {
        switch self {
        case .success(let text), .info(let text), .error(let text):
            return text
        }
    }
}

enum SocialLoginProvider: String, CaseIterable, Identifiable {
    // CaseIterable은 ForEach로 모든 소셜 로그인 버튼을 렌더링할 때 사용한다.
    case apple
    case kakao

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .apple:
            return "Apple"
        case .kakao:
            return "카카오"
        }
    }

    var iconName: String {
        switch self {
        case .apple:
            return "apple.logo"
        case .kakao:
            return "message.fill"
        }
    }
}
