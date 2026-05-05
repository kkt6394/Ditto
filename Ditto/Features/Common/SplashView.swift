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

    private let onFinish: @MainActor () -> Void

    init(onFinish: @escaping @MainActor () -> Void) {
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
            try? await Task.sleep(for: Self.minimumDisplay)
            onFinish()
        }
    }
}
