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

    var body: some View {
        if hasCompletedBootChecks {
            authenticatedDestination
        } else {
            SplashView(onFinish: { hasCompletedBootChecks = true })
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

#Preview {
    ContentView()
}
