//
//  SignUpViewModel.swift
//  Ditto
//
//  Created by 김기태 on 4/23/26.
//

import Foundation
import Observation

// 네트워크 결과가 UI 상태를 바꾸므로 ViewModel 전체를 MainActor에 고정해 화면 갱신을 안전하게 만든다.
@MainActor
@Observable
final class SignUpViewModel {
    // @Observable은 저장 프로퍼티 변경을 View에 알려주므로 @Published 없이도 SwiftUI가 다시 그려진다.
    var email = ""
    var password = ""
    var nick = ""
    var phoneNum = ""
    var introduction = ""
    private(set) var isSubmitting = false
    private(set) var message: SignUpMessage?
    // 이메일 중복검사 결과를 enum 한 값으로 표현해 View가 분기를 깔끔하게 처리할 수 있다.
    private(set) var emailCheckState: EmailCheckState = .idle

    private let networkManagerProvider: @MainActor () throws -> any NetworkManaging
    // 디바운스/중복 호출을 막기 위해 진행 중인 검사 Task를 보관한다.
    private var emailCheckTask: Task<Void, Never>?
    // 같은 이메일을 반복 검사하지 않기 위해 마지막으로 서버 응답을 받은 이메일을 보관한다.
    private var lastCheckedEmail: String?

    convenience init() {
        let authManager = AuthManager()

        self.init {
            // 기본 실행 경로에서는 앱 설정값을 읽어 실제 NetworkManager를 만든다.
            NetworkManager(configuration: try AppConfiguration(), authManager: authManager)
        }
    }

    convenience init(authManager: any AuthManaging) {
        self.init {
            // 기본 실행 경로에서는 앱 설정값을 읽어 실제 NetworkManager를 만든다.
            NetworkManager(configuration: try AppConfiguration(), authManager: authManager)
        }
    }

    init(
        networkManagerProvider: @escaping @MainActor () throws -> any NetworkManaging
    ) {
        self.networkManagerProvider = networkManagerProvider
    }

    convenience init(networkManager: any NetworkManaging) {
        // 테스트에서는 실제 URLSession 대신 StubNetworkManager를 주입해 네트워크 없이 흐름을 검증한다.
        self.init {
            networkManager
        }
    }

    var isSignUpButtonEnabled: Bool {
        // 버튼 활성화 조건을 ViewModel에 두면 View는 화면 표현에만 집중할 수 있다.
        // 서버에서 사용 가능 응답을 받은 이메일이어야만 가입을 시도할 수 있게 막는다.
        !trimmedEmail.isEmpty && !password.isEmpty && !trimmedNick.isEmpty
            && !isSubmitting && isEmailVerified
    }

    // 현재 emailCheckState가 사용 가능 상태인지 외부에서 쉽게 판별하기 위한 헬퍼다.
    var isEmailVerified: Bool {
        if case .available = emailCheckState { return true }
        return false
    }

    // 이메일 입력이 바뀔 때마다 호출돼 디바운스 후 서버 검사를 수행한다.
    func scheduleEmailCheck() {
        // 진행 중이던 이전 검사는 즉시 취소해 최신 입력값에 대한 결과만 반영한다.
        emailCheckTask?.cancel()
        let target = trimmedEmail

        if target.isEmpty {
            emailCheckState = .idle
            lastCheckedEmail = nil
            return
        }

        // @ 기호가 없으면 서버까지 가지 않고 클라이언트에서 형식 오류로 처리한다.
        if !target.contains("@") {
            emailCheckState = .formatInvalid
            lastCheckedEmail = nil
            return
        }

        // 같은 이메일이 이미 사용 가능으로 검증됐다면 다시 호출하지 않는다.
        if target == lastCheckedEmail, case .available = emailCheckState {
            return
        }

        emailCheckState = .checking
        emailCheckTask = Task { [weak self] in
            // 600ms 디바운스: 사용자가 타이핑을 멈춘 직후 한 번만 호출되게 한다.
            try? await Task.sleep(for: .milliseconds(600))
            if Task.isCancelled { return }
            await self?.performEmailCheck(email: target)
        }
    }

    func performEmailCheck(email: String) async {
        do {
            let networkManager = try networkManagerProvider()
            let response: EmailValidationResponse = try await networkManager.request(
                AuthRouter.validateEmail(EmailValidationRequest(email: email))
            )
            if Task.isCancelled { return }
            emailCheckState = .available(response.message)
            lastCheckedEmail = email
        } catch {
            if Task.isCancelled { return }
            applyEmailCheckError(error, for: email)
        }
    }

    func submitSignUp() async {
        message = nil

        if let error = validate() {
            message = .error(error.message)
            return
        }

        isSubmitting = true
        defer {
            // 성공/실패 어느 경로로 끝나도 로딩 상태가 반드시 해제되도록 defer를 사용한다.
            isSubmitting = false
        }

        do {
            let networkManager = try networkManagerProvider()
            // Router는 endpoint와 body를, NetworkManager는 URLRequest 생성과 실행을 담당한다.
            let response: JoinResponse = try await networkManager.request(AuthRouter.join(makeJoinRequest()))
            message = .success("\(response.nick)님, 회원가입이 완료됐습니다.")
        } catch {
            message = .error(Self.makeErrorMessage(from: error))
        }
    }

    func validate() -> SignUpValidationError? {
        // 서버 요청 전에 빠르게 걸러낼 수 있는 입력 오류는 클라이언트에서 먼저 검증한다.
        if trimmedEmail.isEmpty {
            return .emptyEmail
        }

        if !trimmedEmail.contains("@") {
            return .invalidEmail
        }

        if password.isEmpty {
            return .emptyPassword
        }

        if password.count < SignUpRule.minimumPasswordLength {
            return .shortPassword(minLength: SignUpRule.minimumPasswordLength)
        }

        if !SignUpRule.hasRequiredPasswordCharacters(password) {
            return .invalidPasswordFormat
        }

        if trimmedNick.isEmpty {
            return .emptyNick
        }

        if trimmedNick.count < SignUpRule.minimumNickLength {
            return .shortNick(minLength: SignUpRule.minimumNickLength)
        }

        return nil
    }
}

private extension SignUpViewModel {
    var trimmedEmail: String {
        email.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedNick: String {
        nick.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func makeJoinRequest() -> JoinRequest {
        // 선택 입력값은 빈 문자열을 nil로 바꿔 서버에 의미 없는 빈 값을 보내지 않는다.
        JoinRequest(
            email: trimmedEmail,
            password: password,
            nick: trimmedNick,
            phoneNum: optionalText(from: phoneNum),
            introduction: optionalText(from: introduction)
        )
    }

    func optionalText(from text: String) -> String? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedText.isEmpty ? nil : trimmedText
    }

    static func makeErrorMessage(from error: Error) -> String {
        NetworkErrorMapper.userMessage(from: error, fallback: "회원가입 요청에 실패했습니다.")
    }

    static func makeNetworkErrorMessage(from error: NetworkError) -> String {
        NetworkErrorMapper.networkUserMessage(from: error, fallback: "회원가입 요청에 실패했습니다.")
    }

    // 이메일 검사 실패는 status code별로 의미가 다르므로 분리해서 상태에 매핑한다.
    func applyEmailCheckError(_ error: Error, for email: String) {
        if case let NetworkError.statusCode(code, message, _) = error {
            switch code {
            case 409:
                emailCheckState = .unavailable(message ?? "이미 사용 중인 이메일입니다.")
                lastCheckedEmail = email
                return
            case 400:
                emailCheckState = .formatInvalid
                lastCheckedEmail = nil
                return
            default:
                break
            }
        }

        let fallback = "이메일 확인에 실패했습니다."
        emailCheckState = .error(NetworkErrorMapper.userMessage(from: error, fallback: fallback))
        lastCheckedEmail = nil
    }
}

enum SignUpRule {
    // 정책 값은 enum namespace에 모아두면 테스트와 ViewModel에서 같은 기준을 공유할 수 있다.
    static let minimumPasswordLength = 8
    static let minimumNickLength = 2

    static func hasRequiredPasswordCharacters(_ password: String) -> Bool {
        // 서버 비밀번호 규칙과 동일하게 영문, 숫자, 특수문자를 각각 1개 이상 요구한다.
        let hasLetter = password.range(of: "[A-Za-z]", options: .regularExpression) != nil
        let hasNumber = password.range(of: "[0-9]", options: .regularExpression) != nil
        let hasSpecialCharacter = password.range(of: "[@$!%*#?&]", options: .regularExpression) != nil

        return hasLetter && hasNumber && hasSpecialCharacter
    }
}

enum SignUpValidationError: Equatable {
    // 검증 실패 원인을 enum으로 표현하면 테스트에서 문자열보다 안정적으로 비교할 수 있다.
    case emptyEmail
    case invalidEmail
    case emptyPassword
    case shortPassword(minLength: Int)
    case invalidPasswordFormat
    case emptyNick
    case shortNick(minLength: Int)

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
        case .invalidPasswordFormat:
            return "비밀번호는 영문, 숫자, 특수문자를 모두 포함해 주세요."
        case .emptyNick:
            return "닉네임을 입력해 주세요."
        case .shortNick(let minLength):
            return "닉네임은 \(minLength)자 이상 입력해 주세요."
        }
    }
}

// 이메일 중복검사 결과를 6단계 상태로 표현해 View가 색·문구·아이콘을 분기할 수 있게 한다.
enum EmailCheckState: Equatable {
    case idle
    case checking
    case available(String)
    case unavailable(String)
    case formatInvalid
    case error(String)
}

enum SignUpMessage: Equatable {
    // 화면 메시지는 성공/실패 타입을 함께 들고 있어 View가 색상과 아이콘을 쉽게 분기할 수 있다.
    case success(String)
    case error(String)

    var text: String {
        switch self {
        case .success(let text), .error(let text):
            return text
        }
    }
}
