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
    private let pushTokenStore: any PushNotificationTokenStoring

    /// 모든 의존성을 외부에서 주입하는 단일 designated initializer.
    /// 프로덕션 진입점은 `init(authManager:)` convenience 또는 테스트용 extension의
    /// `init(networkManager:...)` convenience를 통해 호출한다.
    init(
        networkManagerProvider: @escaping @MainActor () throws -> any NetworkManaging,
        authManager: any AuthManaging,
        kakaoLoginService: any KakaoLoginServicing,
        pushTokenStore: any PushNotificationTokenStoring = PushNotificationTokenStore.shared
    ) {
        self.networkManagerProvider = networkManagerProvider
        self.authManager = authManager
        self.kakaoLoginService = kakaoLoginService
        self.pushTokenStore = pushTokenStore
    }

    /// 프로덕션 진입점 — 외부에서 AuthManager 인스턴스를 받아 NetworkManager 생성에 재사용한다.
    /// 동일 authManager 인스턴스를 networkManager·LoginViewModel이 공유해야 토큰 갱신이 일관된다.
    convenience init(authManager: any AuthManaging) {
        self.init(
            networkManagerProvider: {
                NetworkManager(configuration: try AppConfiguration(), authManager: authManager)
            },
            authManager: authManager,
            kakaoLoginService: KakaoLoginService(),
            pushTokenStore: PushNotificationTokenStore.shared
        )
    }

    var isLoginButtonEnabled: Bool {
        // 버튼 활성화 로직을 ViewModel에 두면 View 테스트 없이도 입력 정책을 검증할 수 있다.
        !trimmedEmail.isEmpty && !password.isEmpty && !isSubmitting
    }

    func presentSignOutNoticeIfNeeded() {
        // 세션 만료로 강제 로그아웃된 경우에만 한 번 안내한다.
        // 사용자가 직접 로그아웃한 경우엔 별도 토스트를 띄우지 않는다.
        guard authManager.lastSignOutReason == .sessionExpired else {
            return
        }

        message = .info("세션이 만료되어 다시 로그인이 필요해요.")
        authManager.consumeSignOutReason()
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
            // 본인 user_id를 캐시 — 본인 글/댓글 판별 등 모든 화면에서 fetch 없이 즉시 사용 가능.
            authManager.setCurrentUserId(response.userId)
            await updateDeviceTokenIfNeeded(using: networkManager)
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
            // 본인 user_id를 캐시 — 본인 글/댓글 판별 등 모든 화면에서 fetch 없이 즉시 사용 가능.
            authManager.setCurrentUserId(response.userId)
            await updateDeviceTokenIfNeeded(using: networkManager)
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
            // 본인 user_id를 캐시 — 본인 글/댓글 판별 등 모든 화면에서 fetch 없이 즉시 사용 가능.
            authManager.setCurrentUserId(response.userId)
            await updateDeviceTokenIfNeeded(using: networkManager)
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

    func updateDeviceTokenIfNeeded(using networkManager: any NetworkManaging) async {
        guard let deviceToken = pushTokenStore.currentToken else {
            return
        }

        do {
            try await networkManager.send(AuthRouter.updateDeviceToken(DeviceTokenRequest(deviceToken: deviceToken)))
        } catch {
            // 디바이스 토큰 갱신 실패는 로그인 자체를 막지 않고, 다음 로그인/토큰 갱신 때 다시 시도한다.
            #if DEBUG
            print("Device token update failed: \(error)")
            #endif
        }
    }

    static func makeErrorMessage(from error: Error) -> String {
        // 카카오 SDK 전용 에러는 ViewModel 측 도메인 메시지로 처리하고, 그 외는 공통 mapper에 위임한다.
        switch error {
        case KakaoLoginServiceError.missingNativeAppKey:
            return "카카오 앱 키를 확인해 주세요."
        case KakaoLoginServiceError.missingOAuthToken:
            return "카카오 인증 정보를 확인할 수 없습니다."
        default:
            return NetworkErrorMapper.userMessage(from: error, fallback: "로그인 요청에 실패했습니다.")
        }
    }

    static func makeNetworkErrorMessage(from error: NetworkError) -> String {
        NetworkErrorMapper.networkUserMessage(from: error, fallback: "로그인 요청에 실패했습니다.")
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

// MARK: - Test Helpers

extension LoginViewModel {
    /// 테스트 전용 — networkManager를 직접 주입한다.
    /// 누락된 의존성은 프로덕션 기본값으로 채워지므로 테스트는 필요한 stub만 명시하면 된다.
    /// 기본값을 init body 안에서 생성하는 이유: AuthManager 등이 @MainActor로 격리돼 있어
    /// 디폴트 파라미터(비격리 컨텍스트)에서는 직접 호출할 수 없다.
    convenience init(
        networkManager: any NetworkManaging,
        authManager: (any AuthManaging)? = nil,
        kakaoLoginService: (any KakaoLoginServicing)? = nil,
        pushTokenStore: (any PushNotificationTokenStoring)? = nil
    ) {
        self.init(
            networkManagerProvider: { networkManager },
            authManager: authManager ?? AuthManager(),
            kakaoLoginService: kakaoLoginService ?? KakaoLoginService(),
            pushTokenStore: pushTokenStore ?? PushNotificationTokenStore.shared
        )
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
