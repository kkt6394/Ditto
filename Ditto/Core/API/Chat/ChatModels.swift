//
//  ChatModels.swift
//  Ditto
//
//  Created by Codex on 4/25/26.
//

import Foundation

struct ChatRoomCreateRequestDTO: Encodable, Equatable {
    let opponentId: String

    enum CodingKeys: String, CodingKey {
        case opponentId = "opponent_id"
    }
}

struct ChatSendRequestDTO: Encodable, Equatable {
    let content: String
    let files: [String]?
}

struct ChatFileUploadRequestDTO: Equatable {
    let files: [MultipartFile]
}

struct ChatMessageListQuery: Equatable {
    let roomId: String
    let next: String?
}

struct ChatFileResponseDTO: Decodable, Equatable {
    let files: [String]
}

struct ChatResponseDTO: Decodable, Equatable {
    let chatId: String
    let roomId: String
    let content: String
    let createdAt: String
    let updatedAt: String
    let sender: UserInfoResponseDTO
    let files: [String]
}

struct ChatRoomResponseDTO: Decodable, Equatable {
    let roomId: String
    let createdAt: String
    let updatedAt: String
    let participants: [UserInfoResponseDTO]
    let lastChat: ChatResponseDTO?
}

struct ChatRoomListResponseDTO: Decodable, Equatable {
    let data: [ChatRoomResponseDTO]
}

struct ChatListResponseDTO: Decodable, Equatable {
    let data: [ChatResponseDTO]
}
