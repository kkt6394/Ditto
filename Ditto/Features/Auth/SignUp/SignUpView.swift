//
//  SignUpView.swift
//  Ditto
//
//  Created by 김기태 on 4/23/26.
//

import SwiftUI

struct SignUpView: View {
    @Environment(\.dismiss) private var dismiss
    // View가 소유하는 화면 상태이므로 @State로 ViewModel 생명주기를 관리한다.
    @State private var viewModel: SignUpViewModel
    @State private var isPasswordVisible = false
    @State private var isCompletionAlertPresented = false
    // FocusState를 enum으로 관리하면 다음 입력칸 이동 흐름을 명확하게 표현할 수 있다.
    @FocusState private var focusedField: SignUpField?

    init(authManager: any AuthManaging) {
        _viewModel = State(initialValue: SignUpViewModel(authManager: authManager))
    }

    var body: some View {
        ZStack {
            SignUpColor.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    headerSection
                    formSection
                    footerSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 28)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .onChange(of: viewModel.message) { _, message in
            if case .success = message {
                isCompletionAlertPresented = true
            }
        }
        .alert("회원가입 완료", isPresented: $isCompletionAlertPresented) {
            Button("확인") {
                dismiss()
            }
        } message: {
            Text("로그인 화면에서 다시 로그인해 주세요.")
        }
    }
}

private extension SignUpView {
    var headerSection: some View {
        VStack(spacing: 10) {
            Text("DITTO")
                .font(MainFont.paperlogyBlack(size: 28))
                .foregroundStyle(SignUpColor.accent)

            Text("회원가입")
                .font(MainFont.pretendard(.bold, size: 26))
                .foregroundStyle(SignUpColor.primaryText)

            Text("계정 정보를 입력하고 Ditto를 시작해 보세요.")
                .font(MainFont.pretendard(.medium, size: 14))
                .foregroundStyle(SignUpColor.secondaryText)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 2)
    }

    var formSection: some View {
        VStack(spacing: 14) {
            // 각 입력 컴포넌트는 Binding을 받아 ViewModel 상태를 직접 수정한다.
            SignUpInputField(
                title: "이메일",
                placeholder: "email@example.com",
                text: $viewModel.email,
                keyboardType: .emailAddress,
                submitLabel: .next
            )
            .focused($focusedField, equals: .email)
            .onChange(of: viewModel.email) { _, _ in
                // 입력이 바뀔 때마다 ViewModel이 디바운스 후 서버 검사를 수행한다.
                viewModel.scheduleEmailCheck()
            }
            .onSubmit {
                focusedField = .password
            }

            EmailCheckRow(state: viewModel.emailCheckState)

            SignUpSecureField(
                title: "비밀번호",
                placeholder: "8자 이상 입력해 주세요",
                text: $viewModel.password,
                isPasswordVisible: $isPasswordVisible
            )
            .focused($focusedField, equals: .password)
            .onSubmit {
                focusedField = .nick
            }

            SignUpInputField(
                title: "닉네임",
                placeholder: "ditto",
                text: $viewModel.nick,
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
                keyboardType: .phonePad,
                submitLabel: .next
            )
            .focused($focusedField, equals: .phoneNum)
            .onSubmit {
                focusedField = .introduction
            }

            SignUpInputField(
                title: "소개",
                placeholder: "관심 있는 액티비티를 적어보세요 (선택)",
                text: $viewModel.introduction,
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

            signUpButton
        }
    }

    var signUpButton: some View {
        Button {
            Task {
                // Button action은 동기 클로저이므로 async ViewModel 메서드는 Task 안에서 호출한다.
                await viewModel.submitSignUp()
            }
        } label: {
            Text(viewModel.isSubmitting ? "가입 요청 중..." : "이메일로 가입하기")
                .font(MainFont.pretendard(.bold, size: 16))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(SignUpColor.accent.opacity(viewModel.isSignUpButtonEnabled ? 1 : 0.58))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .disabled(!viewModel.isSignUpButtonEnabled)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isSignUpButtonEnabled)
    }

    var footerSection: some View {
        Text("가입하면 서비스 이용약관과 개인정보 처리방침에 동의하게 됩니다.")
            .font(MainFont.pretendard(.medium, size: 11))
            .foregroundStyle(SignUpColor.tertiaryText)
            .multilineTextAlignment(.center)
    }
}

private enum SignUpColor {
    static let background = Color(red: 0.98, green: 0.98, blue: 0.98)
    static let fieldBackground = Color.white
    static let accent = Color(red: 0.48, green: 0.71, blue: 0.86)
    static let primaryText = Color(red: 0.26, green: 0.26, blue: 0.28)
    static let secondaryText = Color(red: 0.42, green: 0.42, blue: 0.43)
    static let tertiaryText = Color(red: 0.63, green: 0.63, blue: 0.64)
    static let border = Color(red: 0.92, green: 0.92, blue: 0.92)
    static let placeholder = Color(red: 0.48, green: 0.48, blue: 0.50)
}

private struct SignUpInputField: View {
    // 같은 형태의 TextField가 반복되므로 작은 View로 분리해 폼 구조 중복을 줄인다.
    let title: String
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let submitLabel: SubmitLabel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(MainFont.pretendard(.bold, size: 13))
                .foregroundStyle(SignUpColor.primaryText)

            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(MainFont.pretendard(.medium, size: 15))
                        .foregroundStyle(SignUpColor.placeholder)
                }

                TextField("", text: $text)
                    .font(MainFont.pretendard(.medium, size: 15))
                    .foregroundStyle(SignUpColor.primaryText)
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
            .fill(SignUpColor.fieldBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(SignUpColor.border, lineWidth: 1)
            }
    }
}

private struct SignUpSecureField: View {
    // 비밀번호 입력은 SecureField를 사용해야 입력값이 화면에 노출되지 않는다.
    let title: String
    let placeholder: String
    let text: Binding<String>
    let isPasswordVisible: Binding<Bool>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(MainFont.pretendard(.bold, size: 13))
                .foregroundStyle(SignUpColor.primaryText)

            HStack(spacing: 12) {
                ZStack(alignment: .leading) {
                    if text.wrappedValue.isEmpty {
                        Text(placeholder)
                            .font(MainFont.pretendard(.medium, size: 15))
                            .foregroundStyle(SignUpColor.placeholder)
                    }

                    Group {
                        if isPasswordVisible.wrappedValue {
                            TextField("", text: text)
                        } else {
                            SecureField("", text: text)
                        }
                    }
                    .font(MainFont.pretendard(.medium, size: 15))
                    .foregroundStyle(SignUpColor.primaryText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                }

                Button {
                    isPasswordVisible.wrappedValue.toggle()
                } label: {
                    Text(isPasswordVisible.wrappedValue ? "숨김" : "보기")
                        .font(MainFont.pretendard(.bold, size: 13))
                        .foregroundStyle(SignUpColor.accent)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(fieldBackground)
        }
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(SignUpColor.fieldBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(SignUpColor.border, lineWidth: 1)
            }
    }
}

private struct EmailCheckRow: View {
    // 이메일 검사 상태별로 아이콘·문구·색을 한 곳에서 결정해 view body는 분기를 갖지 않게 한다.
    let state: EmailCheckState

    var body: some View {
        if let info = displayInfo {
            HStack(spacing: 6) {
                if case .checking = state {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: info.icon)
                }

                Text(info.text)
            }
            .font(MainFont.pretendard(.medium, size: 12))
            .foregroundStyle(info.color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
        }
    }

    private var displayInfo: DisplayInfo? {
        switch state {
        case .idle:
            return nil
        case .checking:
            return DisplayInfo(
                text: "이메일을 확인하는 중...",
                icon: "circle.dotted",
                color: SignUpColor.secondaryText
            )
        case .available(let message):
            return DisplayInfo(text: message, icon: "checkmark.circle.fill", color: SignUpColor.accent)
        case .unavailable(let message):
            return DisplayInfo(text: message, icon: "xmark.circle.fill", color: Self.errorColor)
        case .formatInvalid:
            return DisplayInfo(
                text: "올바른 이메일 형식으로 입력해 주세요.",
                icon: "exclamationmark.circle.fill",
                color: Self.errorColor
            )
        case .error(let message):
            return DisplayInfo(text: message, icon: "exclamationmark.circle.fill", color: Self.errorColor)
        }
    }

    private struct DisplayInfo {
        let text: String
        let icon: String
        let color: Color
    }

    private static let errorColor = Color(red: 0.72, green: 0.18, blue: 0.14)
}

private struct SignUpMessageRow: View {
    let message: SignUpMessage

    var body: some View {
        // 메시지 타입은 ViewModel이 결정하고, View는 타입에 맞는 시각 표현만 담당한다.
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
        case .error:
            "exclamationmark.circle.fill"
        }
    }

    private var foregroundColor: Color {
        switch message {
        case .success:
            SignUpColor.accent
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
