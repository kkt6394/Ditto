//
//  ChatMessageEntity.swift
//  Ditto
//
//  Created by Codex on 4/29/26.
//

import Foundation
import SwiftData

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
}
