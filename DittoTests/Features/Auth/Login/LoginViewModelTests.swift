//
//  LoginViewModelTests.swift
//  DittoTests
//
//  Created by 김기태 on 4/23/26.
//

import Testing
@testable import Ditto

@MainActor
struct LoginViewModelTests {
    @Test func emptyEmailReturnsValidationError() {
        // 공백만 입력한 이메일도 빈 이메일로 처리되는지 확인한다.
        let viewModel = LoginViewModel()

        viewModel.email = " "
        viewModel.password = "password123"

        #expect(viewModel.validate() == .emptyEmail)
    }

    @Test func invalidEmailReturnsValidationError() {
        let viewModel = LoginViewModel()

        viewModel.email = "ditto"
        viewModel.password = "password123"

        #expect(viewModel.validate() == .invalidEmail)
    }

    @Test func shortPasswordReturnsValidationError() {
        let viewModel = LoginViewModel()

        viewModel.email = "ditto@example.com"
        viewModel.password = "1234567"

        #expect(viewModel.validate() == .shortPassword(minLength: 8))
    }

    @Test func validInputPassesValidation() {
        let viewModel = LoginViewModel()

        viewModel.email = "ditto@example.com"
        viewModel.password = "password123"

        #expect(viewModel.validate() == nil)
    }

    @Test func socialLoginSelectionShowsPreparedMessage() {
        // 아직 API가 연결되지 않은 액션은 사용자에게 준비 중 메시지를 보여준다.
        let viewModel = LoginViewModel()

        viewModel.selectSocialLogin(provider: .apple)

        #expect(viewModel.message == .info("Apple 로그인은 연결 준비 중입니다."))
    }
}
