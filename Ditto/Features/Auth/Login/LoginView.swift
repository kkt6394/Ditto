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

    @State private var viewModel: LoginViewModel
    @State private var isPasswordVisible = false
    @FocusState private var focusedField: Field?

    init(authManager: any AuthManaging) {
        self.authManager = authManager
        _viewModel = State(initialValue: LoginViewModel(authManager: authManager))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 1. 배경 파도 이미지 (화면 너비에 맞춰 크롭되도록 수정)
                Image("LoginBackground")
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .ignoresSafeArea()

                // 2. 그라디언트 오버레이
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.20),
                        Color.black.opacity(0.55),
                        Color.black.opacity(0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                // 3. 콘텐츠 (화면 안에 다 들어오므로 ScrollView 불필요)
                VStack(spacing: 14) {
                        // Ditto 헤더
                        Text("Ditto")
                            .font(.system(size: 56, design: .serif))
                            .italic()
                            .foregroundStyle(.white)
                            .padding(.top, 60)

                        Text("너와 함께하는 짜릿한 경험")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.bottom, 32)

                        // 이메일
                        TextField("이메일", text: $viewModel.email)
                            .textFieldStyle(.plain)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .submitLabel(.next)
                            .focused($focusedField, equals: .email)
                            .onSubmit { focusedField = .password }
                            .colorScheme(.dark)
                            .padding(.horizontal, 16)
                            .frame(height: 50)
                            .frame(maxWidth: .infinity)
                            .background(Color.black.opacity(0.45),
                                        in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(.white.opacity(0.65), lineWidth: 1)
                            )

                        // 비밀번호 + 보기 토글 (박스 안에 토글 포함)
                        HStack(spacing: 8) {
                            Group {
                                if isPasswordVisible {
                                    TextField("비밀번호", text: $viewModel.password)
                                } else {
                                    SecureField("비밀번호", text: $viewModel.password)
                                }
                            }
                            .textFieldStyle(.plain)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .focused($focusedField, equals: .password)
                            .onSubmit {
                                Task { _ = await viewModel.submitLogin() }
                            }
                            .colorScheme(.dark)

                            Button {
                                isPasswordVisible.toggle()
                            } label: {
                                Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.85))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16)
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)
                        .background(Color.black.opacity(0.45),
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.white.opacity(0.65), lineWidth: 1)
                        )

                        if let message = viewModel.message {
                            Text(message.text)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(messageColor(for: message))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(messageColor(for: message).opacity(0.18),
                                            in: RoundedRectangle(cornerRadius: 8))
                        }

                        // 이메일로 로그인 버튼
                        Button {
                            Task { _ = await viewModel.submitLogin() }
                        } label: {
                            HStack {
                                Text(viewModel.isSubmitting ? "로그인 중..." : "이메일로 로그인")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(red: 0.48, green: 0.71, blue: 0.86)
                                        .opacity(viewModel.isLoginButtonEnabled ? 1 : 0.58))
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!viewModel.isLoginButtonEnabled)

                        // 회원가입 버튼
                        NavigationLink {
                            SignUpView(authManager: authManager)
                        } label: {
                            HStack {
                                Text("회원가입")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(.white, lineWidth: 1.5)
                            )
                        }

                        // 또는 디바이더
                        HStack(spacing: 12) {
                            Rectangle()
                                .fill(.white.opacity(0.30))
                                .frame(height: 1)
                            Text("또는")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.70))
                            Rectangle()
                                .fill(.white.opacity(0.30))
                                .frame(height: 1)
                        }
                        .padding(.vertical, 4)

                        // 카카오로 로그인
                        Button {
                            Task { await viewModel.submitKakaoLogin() }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "message.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Color.black.opacity(0.85))
                                Text("카카오로 로그인")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.black.opacity(0.85))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(red: 1.0, green: 0.90, blue: 0.0))
                            )
                        }
                        .buttonStyle(.plain)

                        // Sign in with Apple
                        SignInWithAppleButton(.signIn) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            Task { await handleAppleLogin(result) }
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        // 약관
                        Text("로그인하면 서비스 이용약관과 개인정보 처리방침에 동의하게 됩니다.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                            .padding(.top, 6)
                    }
                .padding(.horizontal, 24)
                .frame(maxWidth: geometry.size.width)
                .padding(.bottom, 40)
                // 콘텐츠 VStack 자체의 keyboardAvoidance를 끈다 (입력 필드가 화면 안에 다 들어오므로 위로 밀 필요 없음).
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            // 키보드 등장 시 background까지 같이 위로 밀리는 현상을 막는다.
            .ignoresSafeArea(.keyboard, edges: .bottom)
            // ZStack 외곽에서 모든 tap을 동시에 잡아 first responder 해제 (button과도 충돌 X)
            .simultaneousGesture(
                TapGesture().onEnded {
                    focusedField = nil
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
            )
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.presentSignOutNoticeIfNeeded()
        }
    }
}

private extension LoginView {
    enum Field: Hashable {
        case email
        case password
    }

    func messageColor(for message: LoginMessage) -> Color {
        switch message {
        case .success, .info:
            return .white
        case .error:
            return Color(red: 0.95, green: 0.45, blue: 0.42)
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

#Preview {
    NavigationStack {
        LoginView(authManager: AuthManager())
    }
}
