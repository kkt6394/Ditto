//
//  SignUpView.swift
//  Ditto
//
//  Created by 김기태 on 4/23/26.
//

import SwiftUI

struct SignUpView: View {
    private let authManager: any AuthManaging
    // View가 소유하는 화면 상태이므로 @State로 ViewModel 생명주기를 관리한다.
    @State private var viewModel: SignUpViewModel
    // FocusState를 enum으로 관리하면 다음 입력칸 이동 흐름을 명확하게 표현할 수 있다.
    @FocusState private var focusedField: SignUpField?

    init(authManager: any AuthManaging) {
        self.authManager = authManager
        _viewModel = State(initialValue: SignUpViewModel(authManager: authManager))
    }

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    headerSection
                    formSection
                    signUpButton
                    guideSection
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 36)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("회원가입")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension SignUpView {
    var background: some View {
        // 배경을 별도 computed property로 분리해 body의 화면 구조를 읽기 쉽게 유지한다.
        LinearGradient(
            colors: [
                Color(red: 0.99, green: 0.93, blue: 0.84),
                Color(red: 0.87, green: 0.96, blue: 0.91),
                Color(red: 0.78, green: 0.90, blue: 0.98)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 48, style: .continuous)
                .fill(Color(red: 0.95, green: 0.50, blue: 0.25).opacity(0.28))
                .frame(width: 210, height: 210)
                .rotationEffect(.degrees(18))
                .blur(radius: 24)
                .offset(x: 76, y: -52)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(Color(red: 0.08, green: 0.34, blue: 0.30).opacity(0.20))
                .frame(width: 260, height: 260)
                .blur(radius: 34)
                .offset(x: -104, y: 84)
        }
    }

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("JOIN DITTO")
                .font(.system(size: 15, weight: .black, design: .rounded))
                .tracking(3)
                .foregroundStyle(.secondary)

            Text("dummy 계정으로\n가입 흐름을 확인해요")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 0.08, green: 0.12, blue: 0.14))
                .lineSpacing(4)

            Text("입력값을 검증한 뒤 실제 회원가입 API로 요청을 보냅니다.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
        }
        .padding(.top, 10)
    }

    var formSection: some View {
        VStack(spacing: 14) {
            // 각 입력 컴포넌트는 Binding을 받아 ViewModel 상태를 직접 수정한다.
            SignUpInputField(
                title: "이메일",
                placeholder: "dummy@example.com",
                text: $viewModel.email,
                systemImage: "envelope.fill",
                keyboardType: .emailAddress,
                submitLabel: .next
            )
            .focused($focusedField, equals: .email)
            .onSubmit {
                focusedField = .password
            }

            SignUpSecureField(
                title: "비밀번호",
                placeholder: "8자 이상 입력",
                text: $viewModel.password
            )
            .focused($focusedField, equals: .password)
            .onSubmit {
                focusedField = .nick
            }

            SignUpInputField(
                title: "닉네임",
                placeholder: "ditto",
                text: $viewModel.nick,
                systemImage: "person.fill",
                keyboardType: .default,
                submitLabel: .next
            )
            .focused($focusedField, equals: .nick)
            .onSubmit {
                focusedField = .phoneNum
            }

            SignUpInputField(
                title: "전화번호",
                placeholder: "01012345678 (선택)",
                text: $viewModel.phoneNum,
                systemImage: "phone.fill",
                keyboardType: .phonePad,
                submitLabel: .next
            )
            .focused($focusedField, equals: .phoneNum)

            SignUpInputField(
                title: "소개",
                placeholder: "관심 있는 액티비티를 적어보세요 (선택)",
                text: $viewModel.introduction,
                systemImage: "sparkles",
                keyboardType: .default,
                submitLabel: .done
            )
            .focused($focusedField, equals: .introduction)
            .onSubmit {
                Task {
                    await viewModel.submitSignUp()
                }
            }

            if let message = viewModel.message {
                SignUpMessageRow(message: message)
            }
        }
    }

    var signUpButton: some View {
        Button {
            Task {
                // Button action은 동기 클로저이므로 async ViewModel 메서드는 Task 안에서 호출한다.
                await viewModel.submitSignUp()
            }
        } label: {
            HStack {
                Text(viewModel.isSubmitting ? "가입 요청 중..." : "dummy 회원가입")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 15, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .foregroundStyle(.white)
            .background(
                Capsule()
                    .fill(signUpButtonColor)
                    .shadow(color: signUpButtonColor.opacity(0.30), radius: 16, y: 8)
            )
        }
        .disabled(!viewModel.isSignUpButtonEnabled)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isSignUpButtonEnabled)
    }

    var guideSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // API optional 필드 처리 방식을 화면에 노출해 테스트용 dummy 화면의 목적을 분명히 한다.
            Label("전화번호, 소개, deviceToken은 서버 요청에서 선택값으로 처리합니다.", systemImage: "checkmark.seal.fill")
            Label("빈 선택값은 request body에서 제외됩니다.", systemImage: "tray.and.arrow.up.fill")
        }
        .font(.system(size: 13, weight: .semibold, design: .rounded))
        .foregroundStyle(Color(red: 0.10, green: 0.35, blue: 0.32).opacity(0.82))
        .padding(18)
        .background(.white.opacity(0.46), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    var signUpButtonColor: Color {
        viewModel.isSignUpButtonEnabled
            ? Color(red: 0.08, green: 0.34, blue: 0.30)
            : Color(red: 0.60, green: 0.68, blue: 0.66)
    }
}

private struct SignUpInputField: View {
    // 같은 형태의 TextField가 반복되므로 작은 View로 분리해 폼 구조 중복을 줄인다.
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

private struct SignUpSecureField: View {
    // 비밀번호 입력은 SecureField를 사용해야 입력값이 화면에 노출되지 않는다.
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
                    .submitLabel(.next)
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

private struct SignUpMessageRow: View {
    let message: SignUpMessage

    var body: some View {
        // 메시지 타입은 ViewModel이 결정하고, View는 타입에 맞는 시각 표현만 담당한다.
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
        case .error:
            "exclamationmark.circle.fill"
        }
    }

    private var foregroundColor: Color {
        switch message {
        case .success:
            Color(red: 0.08, green: 0.34, blue: 0.30)
        case .error:
            Color(red: 0.72, green: 0.18, blue: 0.14)
        }
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(0.10)
    }
}

private enum SignUpField: Hashable {
    case email
    case password
    case nick
    case phoneNum
    case introduction
}

#Preview {
    NavigationStack {
        SignUpView(authManager: AuthManager())
    }
}
