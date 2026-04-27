//
//  DittoApp.swift
//  Ditto
//
//  Created by 김기태 on 4/22/26.
//

import KakaoSDKAuth
import KakaoSDKCommon
import SwiftUI

@main
struct DittoApp: App {
    init() {
        if let kakaoNativeAppKey = Bundle.main.kakaoNativeAppKey {
            KakaoSDK.initSDK(appKey: kakaoNativeAppKey)
        }
    }

    var body: some Scene {
        WindowGroup {
            // 앱의 첫 진입점은 ContentView로 통일해 이후 전역 상태나 라우팅을 이 위치에서 확장할 수 있게 한다.
            ContentView()
                .onOpenURL { url in
                    if AuthApi.isKakaoTalkLoginUrl(url) {
                        _ = AuthController.handleOpenUrl(url: url)
                    }
                }
        }
    }
}
