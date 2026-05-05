//
//  ContentView.swift
//  Ditto
//
//  Created by 김기태 on 4/22/26.
//

import SwiftUI

struct ContentView: View {
    @State private var authManager = AuthManager()
    // 스플래시(헬스체크)가 끝나기 전에는 인증 분기를 노출하지 않는다.
    @State private var hasCompletedBootChecks = false
    private let pushTokenStore: any PushNotificationTokenStoring

    init(pushTokenStore: any PushNotificationTokenStoring = PushNotificationTokenStore.shared) {
        self.pushTokenStore = pushTokenStore
    }

    var body: some View {
        Group {
            if hasCompletedBootChecks {
                authenticatedDestination
            } else {
                // 스플래시는 토큰 유효성을 사전 검증하기 위해 authManager를 그대로 받는다.
                SplashView(authManager: authManager) {
                    hasCompletedBootChecks = true
                }
            }
        }
        .task {
            registerPushTokenSyncHandler()
            // 부팅 직후 이미 저장된 토큰이 있고 인증 상태이면 한 번 동기화한다.
            await syncDeviceTokenIfPossible(token: pushTokenStore.currentToken)
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            // 로그인 직후 이미 알고 있던 푸시 토큰을 서버에 반영해 누락을 막는다.
            guard isAuthenticated else {
                return
            }
            Task {
                await syncDeviceTokenIfPossible(token: pushTokenStore.currentToken)
            }
        }
    }

    @ViewBuilder
    private var authenticatedDestination: some View {
        if authManager.isAuthenticated {
            MainView(authManager: authManager)
        } else {
            // 로그인 화면에서만 회원가입 push 이동이 필요하므로 NavigationStack을 이 분기에만 둔다.
            NavigationStack {
                LoginView(authManager: authManager)
            }
        }
    }
}

private extension ContentView {
    func registerPushTokenSyncHandler() {
        // PushNotificationTokenStore가 새 FCM 토큰을 저장하면 인증 상태일 때만 서버에 PUT 한다.
        pushTokenStore.setTokenUpdateHandler { token in
            Task { @MainActor in
                await syncDeviceTokenIfPossible(token: token)
            }
        }
    }

    func syncDeviceTokenIfPossible(token: String?) async {
        guard let token, authManager.isAuthenticated else {
            return
        }

        do {
            let networkManager = NetworkManager(
                configuration: try AppConfiguration(),
                authManager: authManager
            )
            try await networkManager.send(
                AuthRouter.updateDeviceToken(DeviceTokenRequest(deviceToken: token))
            )
        } catch {
            // 디바이스 토큰 동기화 실패는 사용자 흐름에 영향을 주지 않으므로 조용히 넘긴다.
            #if DEBUG
            print("Device token sync failed: \(error)")
            #endif
        }
    }
}

#Preview {
    ContentView()
}
