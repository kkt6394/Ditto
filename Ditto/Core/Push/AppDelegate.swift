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
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()

        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        requestNotificationAuthorization(application: application)

        // 앱이 완전히 종료된 상태에서 푸시 탭으로 켜진 경우, 그 페이로드는 launchOptions로만 들어온다.
        // didReceive는 호출되지 않으므로 여기서 한 번만 PushNavigator에 적재한다.
        if let remotePayload = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
            Self.routeChatPush(from: remotePayload)
        }

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
        let userInfo = notification.request.content.userInfo

        #if DEBUG
        // 서버가 실제로 보내는 페이로드 키 파악용. 사용자 식별/방 정보 키 존재 여부 확인 후 제거 예정.
        print("Push payload: \(userInfo)")
        #endif

        // 채팅 푸시는 room_id 키를 통해 식별한다. 그 외 푸시는 항상 표시한다.
        guard let roomId = userInfo["room_id"] as? String else {
            return [.banner, .badge, .sound]
        }

        let shouldSilence = await MainActor.run {
            // 옵저빙 중인 채팅 목록이 즉시 갱신되도록 트리거를 발행한 뒤 무음 여부를 결정한다.
            ChatPresence.shared.notifyChatListShouldRefresh()
            return ChatPresence.shared.shouldSilencePush(roomId: roomId)
        }

        return shouldSilence ? [] : [.banner, .badge, .sound]
    }

    func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        // 사용자가 푸시 배너/알림센터 항목을 탭했을 때 호출된다.
        // 포어그라운드/백그라운드 상태 모두 이 경로로 들어오며, terminated 상태는 launchOptions에서 한 번 더 처리된다.
        Self.routeChatPush(from: response.notification.request.content.userInfo)
    }
}

private extension AppDelegate {
    static func routeChatPush(from userInfo: [AnyHashable: Any]) {
        guard let roomId = userInfo["room_id"] as? String else {
            return
        }

        // aps.alert.subtitle에는 송신자 닉네임이 들어온다. 채팅 리스트 캐시 매칭이 실패할 때 fallback 으로 쓴다.
        let opponentNickFallback = (userInfo["aps"] as? [String: Any])
            .flatMap { $0["alert"] as? [String: Any] }
            .flatMap { $0["subtitle"] as? String }

        Task { @MainActor in
            PushNavigator.shared.requestChatRoom(roomId: roomId, opponentNickFallback: opponentNickFallback)
        }
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
