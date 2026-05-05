//
//  PushNotificationTokenStore.swift
//  Ditto
//
//  Created by Codex on 4/28/26.
//

import Foundation

protocol PushNotificationTokenStoring: AnyObject {
    var currentToken: String? { get }

    func save(_ token: String)
    // 외부 컴포넌트(ContentView 등)가 새 토큰 도착 시점에 서버 동기화를 트리거할 수 있도록 콜백을 등록한다.
    func setTokenUpdateHandler(_ handler: ((String) -> Void)?)
}

final class PushNotificationTokenStore: PushNotificationTokenStoring {
    static let shared = PushNotificationTokenStore()

    private let userDefaults: UserDefaults
    private let tokenKey: String
    // AppDelegate가 푸시 토큰을 받아 저장한 직후 알림을 받을 수신자 — UI 계층에서 인증 상태를 보고 서버 PUT을 결정한다.
    private var tokenUpdateHandler: ((String) -> Void)?

    init(
        userDefaults: UserDefaults = .standard,
        tokenKey: String = "push.fcmToken"
    ) {
        self.userDefaults = userDefaults
        self.tokenKey = tokenKey
    }

    var currentToken: String? {
        userDefaults.string(forKey: tokenKey)
    }

    func save(_ token: String) {
        // 같은 토큰을 반복 수신하면 서버 동기화도 의미 없으므로 변경된 경우에만 핸들러를 호출한다.
        let previous = userDefaults.string(forKey: tokenKey)
        // FCM 토큰은 앱 재시작 뒤 로그인해도 서버에 다시 등록할 수 있도록 로컬에 보관한다.
        userDefaults.set(token, forKey: tokenKey)

        guard previous != token else {
            return
        }

        tokenUpdateHandler?(token)
    }

    func setTokenUpdateHandler(_ handler: ((String) -> Void)?) {
        tokenUpdateHandler = handler
    }
}
