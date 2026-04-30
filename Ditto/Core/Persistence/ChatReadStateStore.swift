//
//  ChatReadStateStore.swift
//  Ditto
//
//  Created by 김기태 on 4/30/26.
//

import Foundation

// 방 단위로 마지막으로 본 메시지의 createdAt(ISO8601 문자열)을 보관한다.
// 안 읽은 메시지 카운트를 클라이언트에서 추정하기 위해 사용한다.
struct ChatReadStateStore {
    private let key = "chat.lastReadAt"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func lastReadAt(roomId: String) -> String? {
        let dict = defaults.dictionary(forKey: key) as? [String: String]
        return dict?[roomId]
    }

    func setLastReadAt(_ value: String, roomId: String) {
        var dict = (defaults.dictionary(forKey: key) as? [String: String]) ?? [:]

        // 기존보다 오래된 시점이 들어와 안 읽음 표시가 되살아나는 일을 막는다.
        if let existing = dict[roomId], existing >= value {
            return
        }

        dict[roomId] = value
        defaults.set(dict, forKey: key)
    }
}
