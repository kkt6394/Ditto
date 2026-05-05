//
//  SplashView.swift
//  Ditto
//
//  Created by Codex on 5/5/26.
//

import SwiftUI

// 앱 부팅 시 1회 노출되는 스플래시 화면.
// 점검/강제업데이트 분기는 백엔드 스펙이 잡히면 추가한다.
struct SplashView: View {
    // 너무 빨리 사라져 깜빡이는 걸 막기 위한 최소 노출 시간.
    private static let minimumDisplay: Duration = .milliseconds(800)

    private let authManager: any AuthManaging
    private let onFinish: @MainActor () -> Void

    init(
        authManager: any AuthManaging,
        onFinish: @escaping @MainActor () -> Void
    ) {
        self.authManager = authManager
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            MainScreenPalette.background.ignoresSafeArea()

            VStack(spacing: 24) {
                Text("Ditto")
                    .font(MainFont.paperlogyBlack(size: 48))
                    .foregroundStyle(MainScreenPalette.primaryBlue)
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(MainScreenPalette.primaryBlue)
            }
        }
        .task {
            // 토큰 유효성 검증과 최소 노출 시간을 동시에 진행해 스플래시 체감 시간을 늘리지 않는다.
            async let _: Void = Task.sleep(for: Self.minimumDisplay)
            await validateTokensIfAuthenticated()
            try? await Task.sleep(for: Self.minimumDisplay)
            onFinish()
        }
    }
}

private extension SplashView {
    func validateTokensIfAuthenticated() async {
        // 비로그인 상태에선 검증할 토큰이 없으므로 그대로 종료한다.
        guard authManager.isAuthenticated else {
            return
        }

        do {
            // myProfile은 인증이 필요한 가벼운 GET이므로 토큰 유효성 사전 검사로 적합하다.
            // 419는 NetworkManager가 자동으로 refresh를 시도하고, refresh도 실패하면
            // AuthManager가 .sessionExpired 사유로 sign-out 처리한다. 그 결과 ContentView가
            // 자동으로 로그인 화면으로 분기되며, LoginView가 사유를 받아 토스트를 표시한다.
            let networkManager = NetworkManager(
                configuration: try AppConfiguration(),
                authManager: authManager
            )
            let _: MyInfoResponseDTO = try await networkManager.request(UserRouter.myProfile)
        } catch {
            // 검증 실패는 인터셉터/AuthManager가 sign-out으로 이미 반영했거나, 일시적 네트워크
            // 오류일 수 있다. 후자의 경우 메인 화면 진입 후 첫 API 요청에서 다시 처리되므로 무시한다.
            #if DEBUG
            print("Splash token validation finished with error: \(error)")
            #endif
        }
    }
}
