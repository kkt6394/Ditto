//
//  ChatPresence.swift
//  Ditto
//
//  Created by 김기태 on 4/30/26.
//

import Foundation
import Observation

@Observable
@MainActor
final class ChatPresence {
    static let shared = ChatPresence()

    var isOnChatList = false
    var activeRoomId: String?
    private(set) var pushReceivedTick = 0

    private init() {}

    // 채팅 푸시(room_id 포함) 무음 여부 결정. 비채팅 푸시는 호출 측에서 항상 표시한다.
    func shouldSilencePush(roomId: String?) -> Bool {
        if isOnChatList {
            return true
        }

        if let activeRoomId, let roomId, activeRoomId == roomId {
            return true
        }

        return false
    }

    // 채팅 푸시 도착을 옵저빙 중인 화면(채팅 목록 등)에 알리기 위한 트리거.
    func notifyChatPushReceived() {
        pushReceivedTick &+= 1
    }
}
