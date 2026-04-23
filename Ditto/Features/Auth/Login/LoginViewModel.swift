//
//  LoginViewModel.swift
//  Ditto
//
//  Created by 김기태 on 4/23/26.
//

import Foundation
import Observation

@Observable
final class LoginViewModel {
    var email = ""
    var password = ""
    private(set) var isSubmitting = false
    private(set) var message: LoginMessage?

    let socialProviders = SocialLoginProvider.allCases

    var isLoginButtonEnabled: Bool {
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
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum LoginRule {
    static let minimumPasswordLength = 8
}

enum LoginValidationError: Equatable {
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
