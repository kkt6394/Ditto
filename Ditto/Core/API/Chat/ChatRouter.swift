//
//  ChatRouter.swift
//  Ditto
//
//  Created by Codex on 4/25/26.
//

import Foundation

enum ChatRouter: APIRouter {
    case createRoom(ChatRoomCreateRequestDTO)
    case rooms
    case send(roomId: String, request: ChatSendRequestDTO)
    case messages(ChatMessageListQuery)
    case uploadFiles(roomId: String, request: ChatFileUploadRequestDTO)
}

extension ChatRouter {
    var path: String {
        switch self {
        case .createRoom, .rooms:
            return "v1/chats"
        case .send(let roomId, _):
            return "v1/chats/\(roomId)"
        case .messages(let query):
            return "v1/chats/\(query.roomId)"
        case .uploadFiles(let roomId, _):
            return "v1/chats/\(roomId)/files"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .rooms, .messages:
            return .get
        case .createRoom, .send, .uploadFiles:
            return .post
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .messages(let query):
            // next가 nil이면 키 자체를 빼서 서버가 처음부터 조회하도록 한다.
            return [query.next.map { URLQueryItem(name: "next", value: $0) }].compactMap { $0 }
        case .createRoom, .rooms, .send, .uploadFiles:
            return []
        }
    }

    var body: Encodable? {
        switch self {
        case .createRoom(let request):
            return request
        case .send(_, let request):
            return request
        case .rooms, .messages, .uploadFiles:
            return nil
        }
    }

    var multipartFormData: MultipartFormData? {
        switch self {
        case .uploadFiles(_, let request):
            return MultipartFormData(parts: request.files.map { .file(name: "files", file: $0) })
        case .createRoom, .rooms, .send, .messages:
            return nil
        }
    }

    var requiresAuthentication: Bool {
        true
    }
}
