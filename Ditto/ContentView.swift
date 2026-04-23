//
//  ContentView.swift
//  Ditto
//
//  Created by 김기태 on 4/22/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        // 화면 전환이 필요한 기능은 최상위에서 NavigationStack을 감싸야 하위 View가 NavigationLink를 사용할 수 있다.
        NavigationStack {
            LoginView()
        }
    }
}

#Preview {
    ContentView()
}
