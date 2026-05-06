//
//  ChatRoomViewModel.swift
//  Ditto
//
//  Created by Codex on 5/2/26.
//

import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ChatRoomViewModel {
    let roomId: String
    private(set) var messages: [ChatDisplayMessage] = []
    private(set) var isLoading = false
    private(set) var isSending = false
    private(set) var message: String?
    private(set) var attachments: [ChatComposeAttachment] = []

    private let authManager: any AuthManaging
    private let readStateStore: ChatReadStateStore
    private var currentUserId: String?
    private var socketService: ChatSocketService?

    /// 채팅 파일 업로드 정책 — activity-api-docs.md `POST /v1/chats/{room_id}/files`
    /// 확장자: jpg, png, jpeg, gif, pdf / 용량: 5MB / 개수: 5개
    static let maxAttachmentCount = 5
    static let maxAttachmentBytes = 5 * 1024 * 1024

    init(
        roomId: String,
        authManager: any AuthManaging,
        readStateStore: ChatReadStateStore = ChatReadStateStore()
    ) {
        self.roomId = roomId
        self.authManager = authManager
        self.readStateStore = readStateStore
    }

    var remainingAttachmentSlots: Int {
        max(0, Self.maxAttachmentCount - attachments.count)
    }

    func canSend(text: String) -> Bool {
        guard !isSending else { return false }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = !trimmed.isEmpty
        let hasUploadedAttachment = attachments.contains { $0.uploadedPath != nil }
        let hasUploadingAttachment = attachments.contains { attachment in
            if case .uploading = attachment.state { return true }
            return false
        }

        // 텍스트만 있거나, 업로드 완료된 첨부가 1개 이상일 때 전송 가능.
        // 업로드 진행 중인 첨부가 남아 있으면 그 첨부가 안 실린 채 전송되는 것을 막는다.
        guard hasText || hasUploadedAttachment else { return false }
        if hasUploadingAttachment { return false }
        return true
    }

    func start(modelContext: ModelContext) async {
        await loadMessages(modelContext: modelContext)
        connectSocket(modelContext: modelContext)
    }

    func disconnectSocket() {
        socketService?.disconnect()
        socketService = nil
        markLastReadIfPossible()
        // 사용자가 방을 빠져나오는 시점에 채팅 목록의 안 읽음 카운트가 즉시 갱신되도록 신호를 보낸다.
        ChatPresence.shared.notifyChatListShouldRefresh()
    }

    func isOutgoing(_ chatMessage: ChatResponseDTO, opponentNick: String) -> Bool {
        if let currentUserId {
            return chatMessage.sender.userId == currentUserId
        }

        return chatMessage.sender.nick != opponentNick
    }

    func appendAttachments(_ inputs: [ChatAttachmentInput]) {
        let availableSlots = remainingAttachmentSlots
        guard availableSlots > 0 else {
            message = "한 번에 최대 \(Self.maxAttachmentCount)개까지 첨부할 수 있습니다."
            return
        }

        let limitedInputs = inputs.prefix(availableSlots)
        if inputs.count > availableSlots {
            message = "한 번에 최대 \(Self.maxAttachmentCount)개까지 첨부할 수 있어 일부만 추가했습니다."
        }

        for input in limitedInputs {
            do {
                let prepared = try ChatAttachmentPreparation.prepare(input)
                let attachment = ChatComposeAttachment(
                    id: UUID(),
                    kind: prepared.kind,
                    filename: prepared.filename,
                    mimeType: prepared.mimeType,
                    fileData: prepared.fileData,
                    previewData: prepared.previewData,
                    state: .uploading
                )
                attachments.append(attachment)
                uploadAttachment(attachment)
            } catch let error as ChatAttachmentError {
                message = error.userMessage
            } catch {
                message = "첨부 파일을 준비하지 못했습니다."
            }
        }
    }

    func removeAttachment(_ id: UUID) {
        attachments.removeAll { $0.id == id }
    }

    func send(_ content: String, modelContext: ModelContext) async {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let uploadedPaths = attachments.compactMap { $0.uploadedPath }
        let hasAttachments = !uploadedPaths.isEmpty

        guard !trimmedContent.isEmpty || hasAttachments else {
            return
        }

        // 서버 명세상 content는 required(string).
        // 첨부만 보낼 때 빈 문자열도, 공백 한 글자도 서버가 trim 후 거부("필수값을 채워주세요.")한다.
        // zero-width space(U+200B)는 trim에 잡히지 않아 서버 검증을 통과하면서
        // 화면에는 보이지 않는다. ChatBubble에서는 별도로 정리해 빈 텍스트 버블을 그리지 않는다.
        let payloadContent = trimmedContent.isEmpty ? "\u{200B}" : trimmedContent
        let pendingId = Self.makePendingId()

        do {
            try insertPendingEntity(
                pendingId: pendingId,
                content: payloadContent,
                files: uploadedPaths,
                modelContext: modelContext
            )
        } catch {
            message = Self.makeErrorMessage(from: error, fallbackMessage: "메시지를 임시 저장하지 못했습니다.")
            return
        }

        // 입력 영역은 즉시 비워준다. 실패 시에도 사용자가 다시 타이핑하지 않도록
        // 본문/첨부 정보는 pending 엔티티에 보존된다.
        attachments.removeAll()

        isSending = true
        message = nil
        defer {
            isSending = false
        }

        await performSend(
            pendingId: pendingId,
            content: payloadContent,
            files: uploadedPaths,
            modelContext: modelContext
        )
    }

    func retry(messageId: String, modelContext: ModelContext) async {
        guard let entity = findEntity(chatId: messageId, in: modelContext),
              entity.status == .failed else {
            return
        }

        entity.setStatus(.sending)
        do {
            try modelContext.save()
        } catch {
            message = "재전송 준비 중 오류가 발생했습니다."
            return
        }
        messages = (try? cachedMessages(in: modelContext)) ?? messages

        isSending = true
        defer {
            isSending = false
        }
        await performSend(
            pendingId: entity.chatId,
            content: entity.content,
            files: entity.files,
            modelContext: modelContext
        )
    }

    func discardFailed(messageId: String, modelContext: ModelContext) {
        guard let entity = findEntity(chatId: messageId, in: modelContext),
              entity.status != .sent else {
            return
        }

        modelContext.delete(entity)
        do {
            try modelContext.save()
        } catch {
            message = "실패한 메시지를 지우지 못했습니다."
            return
        }
        messages = (try? cachedMessages(in: modelContext)) ?? messages
    }

    private func markLastReadIfPossible() {
        guard let lastSentCreatedAt = lastSentMessage?.dto.createdAt else {
            return
        }

        readStateStore.setLastReadAt(lastSentCreatedAt, roomId: roomId)
    }

    private var lastSentMessage: ChatDisplayMessage? {
        messages.last { $0.status == .sent }
    }

    private func loadMessages(modelContext: ModelContext) async {
        isLoading = true
        message = nil
        defer {
            isLoading = false
        }

        do {
            messages = try cachedMessages(in: modelContext)
        } catch {
            message = "저장된 채팅 내용을 불러오지 못했습니다."
        }

        do {
            let networkManager = try makeNetworkManager()
            currentUserId = await loadCurrentUserId(using: networkManager)
            // pending/failed 로컬 메시지의 timestamp 가 cursor 로 새어 나가지 않도록 sent 만 본다.
            let cursor = lastSentMessage?.dto.createdAt
            let query = ChatMessageListQuery(roomId: roomId, next: cursor)
            let response: ChatListResponseDTO = try await networkManager.request(ChatRouter.messages(query))
            try store(response.data, in: modelContext)
            messages = try cachedMessages(in: modelContext)
            markLastReadIfPossible()
        } catch {
            message = Self.makeErrorMessage(from: error, fallbackMessage: "채팅 내용을 불러오지 못했습니다.")
        }
    }

    private func connectSocket(modelContext: ModelContext) {
        guard socketService == nil else {
            return
        }

        do {
            let configuration = try AppConfiguration()

            guard let tokens = authManager.tokens else {
                throw NetworkError.missingAuthenticationToken
            }

            let service = ChatSocketService(roomId: roomId, configuration: configuration, tokens: tokens)
            service.onMessage = { [weak self] socketMessage in
                self?.receive(socketMessage, modelContext: modelContext)
            }
            service.onError = { [weak self] errorMessage in
                self?.message = errorMessage
            }
            service.onStatusChange = { status in
                // 소켓 라이브러리 상태를 NetworkMonitor 의 SocketStatus 로 변환해 단일 소스에 반영한다.
                switch status {
                case .connected:
                    NetworkMonitor.shared.update(socketStatus: .connected)
                case .connecting:
                    NetworkMonitor.shared.update(socketStatus: .connecting)
                case .disconnected:
                    NetworkMonitor.shared.update(socketStatus: .disconnected)
                }
            }
            socketService = service
            service.connect()
        } catch {
            message = Self.makeErrorMessage(from: error, fallbackMessage: "실시간 채팅을 연결하지 못했습니다.")
        }
    }

    private func receive(_ socketMessage: ChatResponseDTO, modelContext: ModelContext) {
        do {
            try store([socketMessage], in: modelContext)
            messages = try cachedMessages(in: modelContext)
            markLastReadIfPossible()
        } catch {
            message = "실시간 메시지를 저장하지 못했습니다."
        }
    }

    private func loadCurrentUserId(using networkManager: any NetworkManaging) async -> String? {
        do {
            let response: MyInfoResponseDTO = try await networkManager.request(UserRouter.myProfile)
            return response.userId
        } catch {
            return nil
        }
    }

    private func cachedMessages(in modelContext: ModelContext) throws -> [ChatDisplayMessage] {
        let descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate { message in
                message.roomId == roomId
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        return try modelContext.fetch(descriptor).map(\.displayMessage)
    }

    private func store(_ remoteMessages: [ChatResponseDTO], in modelContext: ModelContext) throws {
        guard !remoteMessages.isEmpty else {
            return
        }

        for remoteMessage in remoteMessages {
            if let cachedMessage = try cachedMessage(chatId: remoteMessage.chatId, in: modelContext) {
                cachedMessage.update(with: remoteMessage)
            } else {
                modelContext.insert(ChatMessageEntity(message: remoteMessage))
            }
        }

        try modelContext.save()
    }

    private func cachedMessage(chatId: String, in modelContext: ModelContext) throws -> ChatMessageEntity? {
        var descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate { message in
                message.chatId == chatId
            }
        )
        descriptor.fetchLimit = 1

        return try modelContext.fetch(descriptor).first
    }

    private func makeNetworkManager() throws -> any NetworkManaging {
        let configuration = try AppConfiguration()
        return NetworkManager(configuration: configuration, authManager: authManager)
    }

    static func makeErrorMessage(from error: Error, fallbackMessage: String) -> String {
        NetworkErrorMapper.userMessage(from: error, fallback: fallbackMessage)
    }
}

private extension ChatRoomViewModel {
    static func makePendingId() -> String {
        "pending-" + UUID().uuidString
    }

    static let pendingDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func findEntity(chatId: String, in modelContext: ModelContext) -> ChatMessageEntity? {
        do {
            return try cachedMessage(chatId: chatId, in: modelContext)
        } catch {
            return nil
        }
    }

    func insertPendingEntity(
        pendingId: String,
        content: String,
        files: [String],
        modelContext: ModelContext
    ) throws {
        let nowString = Self.pendingDateFormatter.string(from: Date())
        let entity = ChatMessageEntity(
            pendingId: pendingId,
            roomId: roomId,
            content: content,
            files: files,
            senderId: currentUserId ?? "",
            senderNick: "",
            senderProfileImage: nil,
            senderIntroduction: nil,
            createdAt: nowString
        )
        modelContext.insert(entity)
        try modelContext.save()
        messages = try cachedMessages(in: modelContext)
    }

    func performSend(
        pendingId: String,
        content: String,
        files: [String],
        modelContext: ModelContext
    ) async {
        do {
            let networkManager = try makeNetworkManager()
            let request = ChatSendRequestDTO(
                content: content,
                files: files.isEmpty ? nil : files
            )
            let response: ChatResponseDTO = try await networkManager.request(
                ChatRouter.send(roomId: roomId, request: request)
            )
            try replacePending(pendingId: pendingId, with: response, modelContext: modelContext)
            messages = try cachedMessages(in: modelContext)
            markLastReadIfPossible()
        } catch {
            markPendingFailed(pendingId: pendingId, modelContext: modelContext)
            message = Self.makeErrorMessage(from: error, fallbackMessage: "메시지를 보내지 못했습니다.")
        }
    }

    func replacePending(
        pendingId: String,
        with response: ChatResponseDTO,
        modelContext: ModelContext
    ) throws {
        if let pending = findEntity(chatId: pendingId, in: modelContext) {
            modelContext.delete(pending)
        }
        try store([response], in: modelContext)
    }

    func markPendingFailed(pendingId: String, modelContext: ModelContext) {
        guard let pending = findEntity(chatId: pendingId, in: modelContext) else {
            return
        }
        pending.setStatus(.failed)
        try? modelContext.save()
        messages = (try? cachedMessages(in: modelContext)) ?? messages
    }

    func uploadAttachment(_ attachment: ChatComposeAttachment) {
        Task { [weak self] in
            guard let self else { return }

            do {
                let networkManager = try self.makeNetworkManager()
                let file = MultipartFile(
                    filename: attachment.filename,
                    mimeType: attachment.mimeType,
                    data: attachment.fileData
                )
                let response: ChatFileResponseDTO = try await networkManager.request(
                    ChatRouter.uploadFiles(
                        roomId: self.roomId,
                        request: ChatFileUploadRequestDTO(files: [file])
                    )
                )

                guard let path = response.files.first else {
                    self.markAttachmentFailed(attachment.id, message: "파일 업로드 응답이 비어 있습니다.")
                    return
                }

                self.markAttachmentUploaded(attachment.id, path: path)
            } catch {
                let message = Self.makeErrorMessage(from: error, fallbackMessage: "파일 업로드에 실패했습니다.")
                self.markAttachmentFailed(attachment.id, message: message)
            }
        }
    }

    func markAttachmentUploaded(_ id: UUID, path: String) {
        guard let index = attachments.firstIndex(where: { $0.id == id }) else { return }
        attachments[index].state = .uploaded(path: path)
    }

    func markAttachmentFailed(_ id: UUID, message: String) {
        guard let index = attachments.firstIndex(where: { $0.id == id }) else { return }
        attachments[index].state = .failed(message: message)
        self.message = message
    }
}
