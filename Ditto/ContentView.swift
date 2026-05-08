//
//  ContentView.swift
//  Ditto
//
//  Created by 김기태 on 4/22/26.
//

import SwiftUI

struct ContentView: View {
    @State private var authManager: AuthManager
    // 스플래시(헬스체크)가 끝나기 전에는 인증 분기를 노출하지 않는다.
    @State private var hasCompletedBootChecks = false
    // 토큰 만료 시 자동 갱신·재시도가 적용된 이미지 로더. 앱 진입점에서 한 번만 만들어 환경에 박는다.
    @State private var imageLoader: (any AuthenticatedImageLoading)?
    private let pushTokenStore: any PushNotificationTokenStoring

    init(pushTokenStore: any PushNotificationTokenStoring = PushNotificationTokenStore.shared) {
        self.pushTokenStore = pushTokenStore
        let initialAuthManager = AuthManager()
        _authManager = State(initialValue: initialAuthManager)
        _imageLoader = State(initialValue: Self.makeImageLoader(authManager: initialAuthManager))
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
        .environment(\.imageLoader, imageLoader)
        .task {
            registerPushTokenSyncHandler()
            // 부팅 직후 이미 저장된 토큰이 있고 인증 상태이면 한 번 동기화한다.
            await syncDeviceTokenIfPossible(token: pushTokenStore.currentToken)
            // 앱이 검증 단계에서 죽어 결제 영수증이 미검증으로 남아 있으면 조용히 다시 검증한다.
            await recoverPendingPaymentValidationIfPossible()
        }
        .onChange(of: authManager.isAuthenticated) { _, isAuthenticated in
            // 로그인 직후 이미 알고 있던 푸시 토큰을 서버에 반영해 누락을 막는다.
            guard isAuthenticated else {
                return
            }
            Task {
                await syncDeviceTokenIfPossible(token: pushTokenStore.currentToken)
                await recoverPendingPaymentValidationIfPossible()
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
    /// 환경 주입용 이미지 로더를 만든다. AppConfiguration이 실패하면 nil을 반환하고,
    /// 그러면 SearchRemoteImage가 기존 단순 로더로 폴백한다(토큰 갱신은 못 받지만 동작은 유지).
    static func makeImageLoader(authManager: AuthManager) -> (any AuthenticatedImageLoading)? {
        guard let configuration = try? AppConfiguration() else {
            return nil
        }
        return NetworkManager(configuration: configuration, authManager: authManager)
    }

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

    func recoverPendingPaymentValidationIfPossible() async {
        // 인증되지 않은 상태에서는 검증 호출에 토큰이 없어 의미 없으므로 다음 기회로 미룬다.
        guard authManager.isAuthenticated else {
            return
        }

        let store = PendingPaymentValidationStore()
        let service = PaymentRecoveryService(store: store) { [authManager] in
            NetworkManager(configuration: try AppConfiguration(), authManager: authManager)
        }
        await service.recoverIfNeeded()
    }
}

#Preview {
    ContentView()
}
