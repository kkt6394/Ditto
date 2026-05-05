//
//  SplashView.swift
//  Ditto
//
//  Created by Codex on 5/5/26.
//

import SwiftUI

// 앱 부팅 시 1회 노출되는 스플래시 화면.
// `GET /v1/common` 헬스체크를 호출한 뒤 인증 분기로 전이한다.
// 응답 스키마가 정의돼 있지 않아 점검/강제업데이트 분기는 추후 백엔드 스펙이 잡히면 추가한다.
struct SplashView: View {
    private let networkManagerProvider: @MainActor () throws -> any NetworkManaging
    private let onFinish: @MainActor () -> Void

    init(
        authManager: any AuthManaging,
        onFinish: @escaping @MainActor () -> Void
    ) {
        self.init(
            networkManagerProvider: {
                let configuration = try AppConfiguration()
                return NetworkManager(configuration: configuration, authManager: authManager)
            },
            onFinish: onFinish
        )
    }

    init(
        networkManagerProvider: @escaping @MainActor () throws -> any NetworkManaging,
        onFinish: @escaping @MainActor () -> Void
    ) {
        self.networkManagerProvider = networkManagerProvider
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
            await runBootChecks()
        }
    }

    private func runBootChecks() async {
        // 네트워크 실패/SeSACKey 오류 등은 부팅을 막지 않고 다음 단계로 통과시킨다.
        do {
            let networkManager = try networkManagerProvider()
            try await networkManager.send(CommonRouter.common)
        } catch {
            #if DEBUG
            print("[SplashView] common healthcheck failed: \(error)")
            #endif
        }
        onFinish()
    }
}
