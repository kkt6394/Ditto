//
//  LoginViewModel.swift
//  Ditto
//
//  Created by 김기태 on 4/23/26.
//

import Foundation
import Observation

// @Observable을 붙이면 SwiftUI View가 이 객체의 저장 프로퍼티 변화를 추적한다.
@Observable
final class LoginViewModel {
    var email = ""
    var password = ""
    private(set) var isSubmitting = false
    private(set) var message: LoginMessage?

    let socialProviders = SocialLoginProvider.allCases

    var isLoginButtonEnabled: Bool {
        // 버튼 활성화 로직을 ViewModel에 두면 View 테스트 없이도 입력 정책을 검증할 수 있다.
        !trimmedEmail.isEmpty && !password.isEmpty && !isSubmitting
    }

    func submitLogin() {
        message = nil

        if let error = validate() {
            message = .error(error.message)
            return
        }

        // API 연동 전까지는 입력 검증 흐름만 확인한다.
        isSubmitting = true
        message = .info("로그인 API 연결 전입니다.")
        isSubmitting = false
    }

    func selectSocialLogin(provider: SocialLoginProvider) {
        message = .info("\(provider.title) 로그인은 연결 준비 중입니다.")
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
    case info(String)
    case error(String)

    var text: String {
        switch self {
        case .info(let text), .error(let text):
            return text
        }
    }
}

enum SocialLoginProvider: String, CaseIterable, Identifiable {
    // CaseIterable은 ForEach로 모든 소셜 로그인 버튼을 렌더링할 때 사용한다.
    case apple
    case kakao
    case google

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .apple:
            return "Apple"
        case .kakao:
            return "Kakao"
        case .google:
            return "Google"
        }
    }

    var iconName: String {
        switch self {
        case .apple:
            return "apple.logo"
        case .kakao:
            return "message.fill"
        case .google:
            return "globe"
        }
    }
}
