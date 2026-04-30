//
//  AppDelegate.swift
//  Ditto
//
//  Created by Codex on 4/28/26.
//

import FirebaseCore
import FirebaseMessaging
import UIKit
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    private let pushTokenStore: any PushNotificationTokenStoring

    override init() {
        pushTokenStore = PushNotificationTokenStore.shared
        super.init()
    }

    init(pushTokenStore: any PushNotificationTokenStoring) {
        self.pushTokenStore = pushTokenStore
        super.init()
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        requestNotificationAuthorization(application: application)

        return true
    }

    func application(
        _: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // APNs 토큰을 FCM에 전달해야 Firebase가 앱 인스턴스의 FCM 토큰을 발급/갱신할 수 있다.
        Messaging.messaging().apnsToken = deviceToken
    }
}

private extension AppDelegate {
    func requestNotificationAuthorization(application: UIApplication) {
        let options: UNAuthorizationOptions = [.alert, .badge, .sound]

        UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, error in
            if let error {
                #if DEBUG
                print("Notification authorization failed: \(error.localizedDescription)")
                #endif
                return
            }

            guard granted else {
                return
            }

            DispatchQueue.main.async {
                application.registerForRemoteNotifications()
            }
        }
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // 푸시 페이로드 키 식별을 위한 임시 로그 (확인 후 제거 예정)
        #if DEBUG
        print("[Push:Foreground] userInfo=\(notification.request.content.userInfo)")
        #endif
        return [.banner, .badge, .sound]
    }

    func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // 사용자가 푸시를 탭하여 앱을 연 시점의 페이로드 (백그라운드 진단용 임시 로그)
        #if DEBUG
        print("[Push:Tapped] userInfo=\(response.notification.request.content.userInfo)")
        #endif
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else {
            return
        }

        pushTokenStore.save(fcmToken)

        // 로그인 성공 시 저장된 토큰을 v1/users/deviceToken으로 전송한다.
        #if DEBUG
        print("FCM registration token: \(fcmToken)")
        #endif
    }
}
