//
//  ContentView.swift
//  Ditto
//
//  Created by 김기태 on 4/22/26.
//

import SwiftUI

struct ContentView: View {
    @State private var isLoggedIn = false

    var body: some View {
        if isLoggedIn {
            MainView()
        } else {
            // 로그인 화면에서만 회원가입 push 이동이 필요하므로 NavigationStack을 이 분기에만 둔다.
            NavigationStack {
                LoginView {
                    isLoggedIn = true
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
