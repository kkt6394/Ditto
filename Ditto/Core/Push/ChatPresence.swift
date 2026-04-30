//
//  ChatPresence.swift
//  Ditto
//
//  Created by 김기태 on 4/30/26.
//

import Foundation

@MainActor
final class ChatPresence {
    static let shared = ChatPresence()

    var isOnChatList = false
    var activeRoomId: String?

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
}
