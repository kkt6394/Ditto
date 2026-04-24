//
//  LoginView.swift
//  Ditto
//
//  Created by 김기태 on 4/23/26.
//

import SwiftUI

struct LoginView: View {
    let onLoginSuccess: () -> Void

    // 로그인 화면이 직접 소유하는 상태이므로 @State로 ViewModel을 생성한다.
    @State private var viewModel = LoginViewModel()
    // enum 기반 focus 관리는 문자열 key보다 오타에 안전하다.
    @FocusState private var focusedField: LoginField?

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    headerSection
                    formSection
                    loginButton
                    socialLoginSection
                    footerSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 48)
            }
            .scrollIndicators(.hidden)
        }
    }
}

private extension LoginView {
    var background: some View {
        // 배경 레이어를 분리하면 실제 콘텐츠 배치와 장식 코드를 독립적으로 읽을 수 있다.
        LinearGradient(
            colors: [
                Color(red: 0.98, green: 0.96, blue: 0.90),
                Color(red: 0.90, green: 0.97, blue: 0.94),
                Color(red: 0.82, green: 0.91, blue: 0.98)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(Color(red: 1.00, green: 0.74, blue: 0.42).opacity(0.42))
                .frame(width: 220, height: 220)
                .blur(radius: 28)
                .offset(x: 82, y: -64)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(Color(red: 0.18, green: 0.55, blue: 0.48).opacity(0.22))
                .frame(width: 260, height: 260)
                .blur(radius: 36)
                .offset(x: -96, y: 96)
        }
    }

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("DITTO")
                .font(.system(size: 18, weight: .black, design: .rounded))
                .tracking(4)
                .foregroundStyle(.secondary)

            Text("오늘의 경험을\n가볍게 시작해요")
                .font(.system(size: 36, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.08, green: 0.12, blue: 0.14))
                .lineSpacing(4)

            Text("투어, 액티비티, 체험 상품을 이어서 탐색하려면 로그인해 주세요.")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
        }
        .padding(.top, 24)
    }

    var formSection: some View {
        VStack(spacing: 14) {
            // 입력값은 Binding으로 ViewModel에 연결해 별도 onChange 없이 상태가 동기화된다.
            LoginInputField(
                title: "이메일",
                placeholder: "ditto@example.com",
                text: $viewModel.email,
                systemImage: "envelope.fill",
                keyboardType: .emailAddress,
                submitLabel: .next
            )
            .focused($focusedField, equals: .email)
            .onSubmit {
                focusedField = .password
            }

            LoginSecureField(
                title: "비밀번호",
                placeholder: "8자 이상 입력",
                text: $viewModel.password
            )
            .focused($focusedField, equals: .password)
            .onSubmit {
                Task {
                    let didLogin = await viewModel.submitLogin()

                    if didLogin {
                        onLoginSuccess()
                    }
                }
            }

            if let message = viewModel.message {
                MessageRow(message: message)
            }
        }
    }

    var loginButton: some View {
        Button {
            Task {
                // Button action은 동기 클로저이므로 async ViewModel 메서드는 Task로 감싼다.
                let didLogin = await viewModel.submitLogin()

                if didLogin {
                    onLoginSuccess()
                }
            }
        } label: {
            HStack {
                Text(viewModel.isSubmitting ? "로그인 중..." : "로그인")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .foregroundStyle(.white)
            .background(
                Capsule()
                    .fill(loginButtonColor)
                    .shadow(color: loginButtonColor.opacity(0.32), radius: 16, y: 8)
            )
        }
        .disabled(!viewModel.isLoginButtonEnabled)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoginButtonEnabled)
    }

    var socialLoginSection: some View {
        VStack(spacing: 18) {
            HStack(spacing: 14) {
                Rectangle()
                    .fill(.secondary.opacity(0.18))
                    .frame(height: 1)

                Text("소셜 로그인")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Rectangle()
                    .fill(.secondary.opacity(0.18))
                    .frame(height: 1)
            }

            VStack(spacing: 10) {
                ForEach(viewModel.socialProviders) { provider in
                    SocialLoginButton(provider: provider) {
                        viewModel.selectSocialLogin(provider: provider)
                    }
                }
            }
        }
    }

    var footerSection: some View {
        HStack(spacing: 8) {
            Button("비밀번호 찾기") {
                viewModel.selectForgotPassword()
            }

            Text("|")
                .foregroundStyle(.secondary.opacity(0.45))

            NavigationLink {
                // NavigationStack은 ContentView에서 제공하므로 여기서는 목적지만 선언하면 된다.
                SignUpView()
            } label: {
                Text("회원가입")
            }
        }
        .font(.system(size: 14, weight: .bold, design: .rounded))
        .frame(maxWidth: .infinity)
        .tint(Color(red: 0.10, green: 0.35, blue: 0.32))
    }

    var loginButtonColor: Color {
        viewModel.isLoginButtonEnabled
            ? Color(red: 0.08, green: 0.34, blue: 0.30)
            : Color(red: 0.60, green: 0.68, blue: 0.66)
    }
}

#Preview {
    NavigationStack {
        LoginView(onLoginSuccess: {})
    }
}

private struct LoginInputField: View {
    // 로그인/회원가입 폼에서 반복되는 입력 UI를 작은 View로 분리해 재사용성을 높인다.
    let title: String
    let placeholder: String
    @Binding var text: String
    let systemImage: String
    let keyboardType: UIKeyboardType
    let submitLabel: SubmitLabel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(Color(red: 0.08, green: 0.34, blue: 0.30))
                    .frame(width: 20)

                TextField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(keyboardType)
                    .submitLabel(submitLabel)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(fieldBackground)
        }
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.white.opacity(0.82))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.72), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.06), radius: 16, y: 8)
    }
}

private struct LoginSecureField: View {
    // SecureField는 TextField와 API가 다르므로 별도 컴포넌트로 분리한다.
    let title: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Color(red: 0.08, green: 0.34, blue: 0.30))
                    .frame(width: 20)

                SecureField(placeholder, text: $text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(fieldBackground)
        }
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.white.opacity(0.82))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.72), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.06), radius: 16, y: 8)
    }
}

private struct MessageRow: View {
    let message: LoginMessage

    var body: some View {
        // ViewModel의 메시지 타입에 따라 아이콘과 색상만 다르게 표현한다.
        Label(message.text, systemImage: iconName)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        case .success:
            Color(red: 0.08, green: 0.34, blue: 0.30)
        case .info:
            Color(red: 0.08, green: 0.34, blue: 0.30)
        case .error:
            Color(red: 0.72, green: 0.18, blue: 0.14)
        }
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(0.10)
    }
}

private struct SocialLoginButton: View {
    let provider: SocialLoginProvider
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: provider.iconName)
                    .frame(width: 20)

                Text("\(provider.title)로 계속하기")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .foregroundStyle(.primary)
            .background(.white.opacity(0.72), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.8), lineWidth: 1)
            }
        }
    }
}

private enum LoginField: Hashable {
    case email
    case password
}

#Preview {
    LoginView(onLoginSuccess: {})
}
