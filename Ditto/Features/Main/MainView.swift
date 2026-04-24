//
//  MainView.swift
//  Ditto
//
//  Created by 김기태 on 4/24/26.
//

import SwiftUI

struct MainView: View {
    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            Text("메인 화면")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.black)
        }
    }
}

#Preview {
    MainView()
}
