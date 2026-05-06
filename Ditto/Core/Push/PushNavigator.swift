//
//  PushNavigator.swift
//  Ditto
//
//  Created by 김기태 on 5/6/26.
//

import Foundation
import Observation

// 푸시 탭으로 들어온 채팅방 진입 요청을 MainView까지 전달하기 위한 다리.
// AppDelegate(콜백 컨텍스트)와 MainView(뷰 계층) 사이를 직접 잇기 어렵기 때문에
// 싱글톤 옵저버블을 두고, 요청자는 set, 소비자는 read 후 consume 하는 단방향 흐름으로 단순화한다.
@Observable
@MainActor
final class PushNavigator {
    static let shared = PushNavigator()

    // 푸시 탭으로 진입 요청된 채팅방 정보. MainView가 옵저빙해서 처리 후 consume() 으로 비운다.
    private(set) var pendingChat: PendingChat?

    private init() {}

    func requestChatRoom(roomId: String, opponentNickFallback: String?) {
        pendingChat = PendingChat(roomId: roomId, opponentNickFallback: opponentNickFallback)
    }

    func consume() {
        pendingChat = nil
    }
}

extension PushNavigator {
    struct PendingChat: Equatable {
        let roomId: String
        // 페이로드 aps.alert.subtitle에서 추출한 송신자 닉네임.
        // 채팅 리스트 캐시 매칭이 실패했을 때 fallback 으로 사용한다.
        let opponentNickFallback: String?
    }
}
