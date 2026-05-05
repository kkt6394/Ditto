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
    // 너무 빨리 사라져 깜빡이는 걸 막기 위한 최소 노출 시간.
    private static let minimumDisplay: Duration = .milliseconds(800)
    // 응답이 늦어도 부팅이 길어지지 않도록 헬스체크 자체에 걸어두는 상한.
    private static let healthCheckTimeout: Duration = .seconds(2)

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
        // 최소 노출 시간을 헬스체크와 병렬로 흘려보내, 둘 중 더 늦게 끝나는 쪽까지 기다린다.
        async let minimumDisplay: Void = sleepForMinimumDisplay()
        await performHealthCheckWithTimeout()
        try? await minimumDisplay
        onFinish()
    }

    private func sleepForMinimumDisplay() async throws {
        try await Task.sleep(for: Self.minimumDisplay)
    }

    private func performHealthCheckWithTimeout() async {
        // 헬스체크와 타임아웃을 경쟁시켜 먼저 끝나는 쪽으로 종료한다.
        // 네트워크 실패/SeSACKey 오류 등은 부팅을 막지 않고 다음 단계로 통과시킨다.
        await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor [networkManagerProvider] in
                do {
                    let networkManager = try networkManagerProvider()
                    try await networkManager.send(CommonRouter.common)
                } catch {
                    #if DEBUG
                    print("[SplashView] common healthcheck failed: \(error)")
                    #endif
                }
            }
            group.addTask {
                try? await Task.sleep(for: Self.healthCheckTimeout)
            }
            await group.next()
            group.cancelAll()
        }
    }
}
