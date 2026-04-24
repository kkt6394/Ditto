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

    private let networkManagerProvider: @MainActor () throws -> any NetworkManaging
    private let authManager: any AuthManaging

    convenience init() {
        let authManager = AuthManager()

        self.init(
            networkManagerProvider: {
                // 기본 실행 경로에서는 앱 설정값을 읽어 실제 NetworkManager를 만든다.
                NetworkManager(configuration: try AppConfiguration(), authManager: authManager)
            },
            authManager: authManager
        )
    }

    convenience init(authManager: any AuthManaging) {
        self.init(
            networkManagerProvider: {
                // 기본 실행 경로에서는 앱 설정값을 읽어 실제 NetworkManager를 만든다.
                NetworkManager(configuration: try AppConfiguration(), authManager: authManager)
            },
            authManager: authManager
        )
    }

    init(
        networkManagerProvider: @escaping @MainActor () throws -> any NetworkManaging,
        authManager: any AuthManaging
    ) {
        self.networkManagerProvider = networkManagerProvider
        self.authManager = authManager
    }

    convenience init(networkManager: any NetworkManaging) {
        self.init(networkManager: networkManager, authManager: AuthManager())
    }

    init(networkManager: any NetworkManaging, authManager: any AuthManaging) {
        // 테스트에서는 실제 URLSession 대신 StubNetworkManager를 주입해 네트워크 없이 흐름을 검증한다.
        networkManagerProvider = {
            networkManager
        }
        self.authManager = authManager
    }

    var isSignUpButtonEnabled: Bool {
        // 버튼 활성화 조건을 ViewModel에 두면 View는 화면 표현에만 집중할 수 있다.
        !trimmedEmail.isEmpty && !password.isEmpty && !trimmedNick.isEmpty && !isSubmitting
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
            try authManager.authenticate(with: response.tokens)
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
        // ViewModel은 네트워크 계층의 Error를 사용자가 이해할 수 있는 문장으로 변환한다.
        switch error {
        case let error as NetworkError:
            return makeNetworkErrorMessage(from: error)
        case AuthManagerError.tokenSaveFailed:
            return "인증 정보를 저장할 수 없습니다."
        case AppConfigurationError.missingValue, AppConfigurationError.invalidURL:
            return "API 설정값을 확인해 주세요."
        default:
            return "회원가입 요청에 실패했습니다."
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
            return message ?? "회원가입 요청에 실패했습니다."
        case .encodingFailed:
            return "요청 데이터를 만들 수 없습니다."
        case .decodingFailed:
            return "회원가입 응답을 해석할 수 없습니다."
        case .requestFailed:
            return "네트워크 연결을 확인해 주세요."
        }
    }
}

enum SignUpRule {
    // 정책 값은 enum namespace에 모아두면 테스트와 ViewModel에서 같은 기준을 공유할 수 있다.
    static let minimumPasswordLength = 8
    static let minimumNickLength = 2
}

enum SignUpValidationError: Equatable {
    // 검증 실패 원인을 enum으로 표현하면 테스트에서 문자열보다 안정적으로 비교할 수 있다.
    case emptyEmail
    case invalidEmail
    case emptyPassword
    case shortPassword(minLength: Int)
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
        case .emptyNick:
            return "닉네임을 입력해 주세요."
        case .shortNick(let minLength):
            return "닉네임은 \(minLength)자 이상 입력해 주세요."
        }
    }
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
