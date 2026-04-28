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
}

final class PushNotificationTokenStore: PushNotificationTokenStoring {
    static let shared = PushNotificationTokenStore()

    private let userDefaults: UserDefaults
    private let tokenKey: String

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
        // FCM 토큰은 앱 재시작 뒤 로그인해도 서버에 다시 등록할 수 있도록 로컬에 보관한다.
        userDefaults.set(token, forKey: tokenKey)
    }
}
