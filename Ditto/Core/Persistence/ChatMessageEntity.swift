//
//  ChatMessageEntity.swift
//  Ditto
//
//  Created by Codex on 4/29/26.
//

import Foundation
import SwiftData

// 메시지의 전송 상태. 서버 응답을 받아 저장된 기존 데이터는 모두 sent 로 간주한다.
enum ChatMessageStatus: String, Equatable {
    case sending
    case sent
    case failed
}

@Model
final class ChatMessageEntity {
    @Attribute(.unique) var chatId: String
    var roomId: String
    var content: String
    var createdAt: String
    var updatedAt: String
    var senderId: String
    var senderNick: String
    var senderProfileImage: String?
    var senderIntroduction: String?
    var files: [String]
    // 마이그레이션 안전을 위해 옵셔널. nil 은 sent 로 해석한다.
    var statusRaw: String?

    init(message: ChatResponseDTO) {
        chatId = message.chatId
        roomId = message.roomId
        content = message.content
        createdAt = message.createdAt
        updatedAt = message.updatedAt
        senderId = message.sender.userId
        senderNick = message.sender.nick
        senderProfileImage = message.sender.profileImage
        senderIntroduction = message.sender.introduction
        files = message.files
        statusRaw = ChatMessageStatus.sent.rawValue
    }

    // 사용자가 메시지를 막 보낸 시점에 로컬에서 만들어 두는 sending 상태 엔티티.
    init(
        pendingId: String,
        roomId: String,
        content: String,
        files: [String],
        senderId: String,
        senderNick: String,
        senderProfileImage: String?,
        senderIntroduction: String?,
        createdAt: String
    ) {
        self.chatId = pendingId
        self.roomId = roomId
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.senderId = senderId
        self.senderNick = senderNick
        self.senderProfileImage = senderProfileImage
        self.senderIntroduction = senderIntroduction
        self.files = files
        self.statusRaw = ChatMessageStatus.sending.rawValue
    }

    func update(with message: ChatResponseDTO) {
        roomId = message.roomId
        content = message.content
        createdAt = message.createdAt
        updatedAt = message.updatedAt
        senderId = message.sender.userId
        senderNick = message.sender.nick
        senderProfileImage = message.sender.profileImage
        senderIntroduction = message.sender.introduction
        files = message.files
        statusRaw = ChatMessageStatus.sent.rawValue
    }

    var status: ChatMessageStatus {
        statusRaw.flatMap(ChatMessageStatus.init(rawValue:)) ?? .sent
    }

    func setStatus(_ newValue: ChatMessageStatus) {
        statusRaw = newValue.rawValue
    }

    var dto: ChatResponseDTO {
        ChatResponseDTO(
            chatId: chatId,
            roomId: roomId,
            content: content,
            createdAt: createdAt,
            updatedAt: updatedAt,
            sender: UserInfoResponseDTO(
                userId: senderId,
                nick: senderNick,
                profileImage: senderProfileImage,
                introduction: senderIntroduction
            ),
            files: files
        )
    }

    var displayMessage: ChatDisplayMessage {
        ChatDisplayMessage(id: chatId, dto: dto, status: status)
    }
}

// 채팅방 화면에 그릴 한 건의 메시지. DTO + 클라이언트 상태를 함께 들고 다닌다.
struct ChatDisplayMessage: Identifiable, Equatable {
    let id: String
    let dto: ChatResponseDTO
    let status: ChatMessageStatus
}
