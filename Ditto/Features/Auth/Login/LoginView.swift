//
//  LoginView.swift
//  Ditto
//
//  Created by 김기태 on 4/23/26.
//

import AuthenticationServices
import SwiftUI

struct LoginView: View {
    private let authManager: any AuthManaging

    // 로그인 화면이 직접 소유하는 상태이므로 @State로 ViewModel을 생성한다.
    @State private var viewModel: LoginViewModel
    @State private var isPasswordVisible = false
    // enum 기반 focus 관리는 문자열 key보다 오타에 안전하다.
    @FocusState private var focusedField: LoginField?

    init(authManager: any AuthManaging) {
        self.authManager = authManager
        _viewModel = State(initialValue: LoginViewModel(authManager: authManager))
    }

    var body: some View {
        ZStack {
            LoginColor.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    formSection
                    socialLoginSection
                    footerSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 52)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private extension LoginView {
    var headerSection: some View {
        VStack(spacing: 10) {
            Text("DITTO")
                .font(MainFont.paperlogyBlack(size: 28))
                .foregroundStyle(LoginColor.accent)

            Text("로그인")
                .font(MainFont.pretendard(.bold, size: 26))
                .foregroundStyle(LoginColor.primaryText)

            Text("이메일 또는 소셜 계정으로 간편하게 시작하세요.")
                .font(MainFont.pretendard(.medium, size: 14))
                .foregroundStyle(LoginColor.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 2)
    }

    var formSection: some View {
        VStack(spacing: 14) {
            LoginTextField(
                title: "이메일",
                placeholder: "email@example.com",
                text: $viewModel.email,
                keyboardType: .emailAddress,
                submitLabel: .next
            )
            .focused($focusedField, equals: .email)
            .onSubmit {
                focusedField = .password
            }

            LoginPasswordField(
                text: $viewModel.password,
                isPasswordVisible: $isPasswordVisible
            )
            .focused($focusedField, equals: .password)
            .onSubmit {
                Task {
                    _ = await viewModel.submitLogin()
                }
            }

            if let message = viewModel.message {
                LoginMessageRow(message: message)
            }

            emailLoginButton
        }
    }

    var emailLoginButton: some View {
        Button {
            Task {
                _ = await viewModel.submitLogin()
            }
        } label: {
            Text(viewModel.isSubmitting ? "로그인 중..." : "이메일로 로그인")
                .font(MainFont.pretendard(.bold, size: 16))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(LoginColor.accent.opacity(viewModel.isLoginButtonEnabled ? 1 : 0.58))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .disabled(!viewModel.isLoginButtonEnabled)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoginButtonEnabled)
    }

    var socialLoginSection: some View {
        VStack(spacing: 16) {
            LoginDivider()

            VStack(spacing: 10) {
                AppleLoginButton { result in
                    Task {
                        await handleAppleLogin(result)
                    }
                }

                KakaoLoginButton {
                    viewModel.selectSocialLogin(provider: .kakao)
                }
            }
        }
    }

    var footerSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 4) {
                Text("아직 계정이 없나요?")
                    .foregroundStyle(LoginColor.secondaryText)

                NavigationLink {
                    // NavigationStack은 ContentView에서 제공하므로 여기서는 목적지만 선언하면 된다.
                    SignUpView(authManager: authManager)
                } label: {
                    Text("가입하기")
                        .foregroundStyle(LoginColor.accent)
                }
            }
            .font(MainFont.pretendard(.medium, size: 13))

            Text("로그인하면 서비스 이용약관과 개인정보 처리방침에 동의하게 됩니다.")
                .font(MainFont.pretendard(.medium, size: 11))
                .foregroundStyle(LoginColor.tertiaryText)
                .multilineTextAlignment(.center)
        }
    }

    func handleAppleLogin(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let identityToken = credential.identityToken,
                let idToken = String(data: identityToken, encoding: .utf8)
            else {
                viewModel.handleAppleLoginFailure(message: "Apple 인증 정보를 확인할 수 없습니다.")
                return
            }

            await viewModel.submitAppleLogin(idToken: idToken)
        case .failure:
            viewModel.handleAppleLoginFailure(message: "Apple 로그인을 완료하지 못했습니다.")
        }
    }
}

private enum LoginColor {
    static let background = Color(red: 0.98, green: 0.98, blue: 0.98)
    static let fieldBackground = Color.white
    static let accent = Color(red: 0.48, green: 0.71, blue: 0.86)
    static let primaryText = Color(red: 0.26, green: 0.26, blue: 0.28)
    static let secondaryText = Color(red: 0.42, green: 0.42, blue: 0.43)
    static let tertiaryText = Color(red: 0.63, green: 0.63, blue: 0.64)
    static let border = Color(red: 0.92, green: 0.92, blue: 0.92)
    static let placeholder = Color(red: 0.48, green: 0.48, blue: 0.50)
}

private struct LoginTextField: View {
    // 입력 필드의 라벨, 테두리, 높이를 디자인 노드와 동일하게 유지한다.
    let title: String
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let submitLabel: SubmitLabel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(MainFont.pretendard(.bold, size: 13))
                .foregroundStyle(LoginColor.primaryText)

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(MainFont.pretendard(.medium, size: 15))
                        .foregroundStyle(LoginColor.placeholder)
                }

                TextField("", text: $text)
                    .font(MainFont.pretendard(.medium, size: 15))
                    .foregroundStyle(LoginColor.primaryText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(keyboardType)
                    .submitLabel(submitLabel)
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(fieldBackground)
        }
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(LoginColor.fieldBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(LoginColor.border, lineWidth: 1)
            }
    }
}

private struct LoginPasswordField: View {
    let text: Binding<String>
    let isPasswordVisible: Binding<Bool>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("비밀번호")
                .font(MainFont.pretendard(.bold, size: 13))
                .foregroundStyle(LoginColor.primaryText)

            HStack(spacing: 12) {
                ZStack(alignment: .leading) {
                    if text.wrappedValue.isEmpty {
                        Text("비밀번호를 입력해 주세요")
                            .font(MainFont.pretendard(.medium, size: 15))
                            .foregroundStyle(LoginColor.placeholder)
                    }

                    Group {
                        if isPasswordVisible.wrappedValue {
                            TextField("", text: text)
                        } else {
                            SecureField("", text: text)
                        }
                    }
                    .font(MainFont.pretendard(.medium, size: 15))
                    .foregroundStyle(LoginColor.primaryText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                }

                Button {
                    isPasswordVisible.wrappedValue.toggle()
                } label: {
                    Text(isPasswordVisible.wrappedValue ? "숨김" : "보기")
                        .font(MainFont.pretendard(.bold, size: 13))
                        .foregroundStyle(LoginColor.accent)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(fieldBackground)
        }
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(LoginColor.fieldBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(LoginColor.border, lineWidth: 1)
            }
    }
}

private struct LoginDivider: View {
    var body: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(LoginColor.border)
                .frame(height: 1)

            Text("또는")
                .font(MainFont.pretendard(.medium, size: 12))
                .foregroundStyle(LoginColor.tertiaryText)

            Rectangle()
                .fill(LoginColor.border)
                .frame(height: 1)
        }
        .frame(height: 20)
    }
}

private struct AppleLoginButton: View {
    let completion: (Result<ASAuthorization, Error>) -> Void

    var body: some View {
        SignInWithAppleButton(.signIn) { request in
            request.requestedScopes = [.fullName, .email]
        } onCompletion: { result in
            completion(result)
        }
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct KakaoLoginButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                KakaoBubbleIcon()
                    .frame(width: 22, height: 20)

                Text("카카오로 로그인")
                    .font(MainFont.pretendard(.bold, size: 16))
                    .foregroundStyle(Color.black.opacity(0.85))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color(red: 1.0, green: 0.90, blue: 0.0))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private struct KakaoBubbleIcon: View {
    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: size.width * 0.5, y: 0))
            path.addCurve(
                to: CGPoint(x: 0, y: size.height * 0.43),
                control1: CGPoint(x: size.width * 0.22, y: 0),
                control2: CGPoint(x: 0, y: size.height * 0.19)
            )
            path.addCurve(
                to: CGPoint(x: size.width * 0.23, y: size.height * 0.79),
                control1: CGPoint(x: 0, y: size.height * 0.58),
                control2: CGPoint(x: size.width * 0.09, y: size.height * 0.71)
            )
            path.addLine(to: CGPoint(x: size.width * 0.18, y: size.height))
            path.addLine(to: CGPoint(x: size.width * 0.42, y: size.height * 0.85))
            path.addCurve(
                to: CGPoint(x: size.width, y: size.height * 0.43),
                control1: CGPoint(x: size.width * 0.93, y: size.height * 0.82),
                control2: CGPoint(x: size.width, y: size.height * 0.61)
            )
            path.addCurve(
                to: CGPoint(x: size.width * 0.5, y: 0),
                control1: CGPoint(x: size.width, y: size.height * 0.19),
                control2: CGPoint(x: size.width * 0.78, y: 0)
            )
            context.fill(path, with: .color(.black))
        }
    }
}

private struct LoginMessageRow: View {
    let message: LoginMessage

    var body: some View {
        Label(message.text, systemImage: iconName)
            .font(MainFont.pretendard(.semibold, size: 13))
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var iconName: String {
        switch message {
        case .success:
            "checkmark.circle.fill"
        case .info:
            "info.circle.fill"
        case .error:
            "exclamationmark.circle.fill"
        }
    }

    private var foregroundColor: Color {
        switch message {
        case .success, .info:
            LoginColor.accent
        case .error:
            Color(red: 0.72, green: 0.18, blue: 0.14)
        }
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(0.10)
    }
}

private enum LoginField: Hashable {
    case email
    case password
}

#Preview {
    NavigationStack {
        LoginView(authManager: AuthManager())
    }
}
