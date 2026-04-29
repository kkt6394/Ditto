//
//  ChatSocketService.swift
//  Ditto
//
//  Created by Codex on 4/29/26.
//

import Foundation
import SocketIO

final class ChatSocketService {
    var onMessage: ((ChatResponseDTO) -> Void)?
    var onError: ((String) -> Void)?

    private let manager: SocketManager
    private let socket: SocketIOClient
    private let decoder: JSONDecoder

    init(roomId: String, configuration: AppConfiguration, tokens: AuthTokens) {
        let socketURL = configuration.baseURL.deletingPath()
        let headers = [
            "SeSACKey": configuration.apiKey,
            "Authorization": tokens.accessToken
        ]

        manager = SocketManager(
            socketURL: socketURL,
            config: [
                .compress,
                .extraHeaders(headers),
                .forceWebsockets(true),
                .reconnects(true)
            ]
        )
        socket = manager.socket(forNamespace: "/chats-\(roomId)")
        decoder = NetworkManager.makeChatSocketDecoder()

        registerHandlers()
    }

    func connect() {
        guard socket.status != .connected && socket.status != .connecting else {
            return
        }

        socket.connect()
    }

    func disconnect() {
        socket.disconnect()
        socket.removeAllHandlers()
        manager.disconnect()
    }
}

private extension ChatSocketService {
    func registerHandlers() {
        socket.on(clientEvent: .connect) { _, _ in }

        socket.on(clientEvent: .error) { [weak self] data, _ in
            self?.notifyError(from: data)
        }

        socket.on(clientEvent: .disconnect) { _, _ in }

        socket.on("chat") { [weak self] data, _ in
            self?.decodeMessage(from: data)
        }

        socket.onAny { [weak self] event in
            guard event.event != "chat" else {
                return
            }

            self?.decodeMessage(from: event.items ?? [])
        }
    }

    func decodeMessage(from data: [Any]) {
        guard let messageData = messageData(from: data.first) else {
            return
        }

        do {
            let message = try decoder.decode(ChatResponseDTO.self, from: messageData)
            Task { @MainActor in
                onMessage?(message)
            }
        } catch {
            return
        }
    }

    func messageData(from payload: Any?) -> Data? {
        switch payload {
        case let data as Data:
            return data
        case let string as String:
            return string.data(using: .utf8)
        case let dictionary as [String: Any]:
            return try? JSONSerialization.data(withJSONObject: dictionary)
        case let array as [Any]:
            guard JSONSerialization.isValidJSONObject(array) else {
                return nil
            }

            return try? JSONSerialization.data(withJSONObject: array)
        default:
            return nil
        }
    }

    func notifyError(from data: [Any]) {
        let detail = data.first.map { "\($0)" } ?? "소켓 연결을 확인해 주세요."

        Task { @MainActor in
            onError?(detail)
        }
    }
}

private extension URL {
    func deletingPath() -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false) else {
            return self
        }

        components.path = ""
        components.query = nil
        components.fragment = nil

        return components.url ?? self
    }
}
