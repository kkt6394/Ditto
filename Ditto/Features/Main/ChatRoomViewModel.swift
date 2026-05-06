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
    // 소켓이 한 번 끊긴 적이 있는지 추적해 첫 연결과 재연결을 구분한다.
    // disconnect→connect 전이만 sync 트리거로 본다.
    private var hasBeenDisconnectedSinceConnect = false
    private var isSyncing = false
    private var lastSyncAt: Date?
    // 재전송 중복 탭을 막기 위한 in-flight 집합. 사용자가 같은 실패 메시지를 연달아 두번 누르면
    // 두 번째 탭은 무시한다.
    private var retryingMessageIds: Set<String> = []

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

        // 입력 영역은 즉시 비워 사용자에게 "받았다"는 신호를 주되, 화면 메시지 목록에는
        // 임시 말풍선을 띄우지 않는다. 결과(성공 or 실패)가 도착할 때 비로소 등장한다.
        attachments.removeAll()

        isSending = true
        message = nil
        defer {
            isSending = false
        }

        do {
            let networkManager = try makeNetworkManager()
            let request = ChatSendRequestDTO(
                content: payloadContent,
                files: hasAttachments ? uploadedPaths : nil
            )
            let response: ChatResponseDTO = try await networkManager.request(
                ChatRouter.send(roomId: roomId, request: request)
            )
            try store([response], in: modelContext)
            messages = try cachedMessages(in: modelContext)
            markLastReadIfPossible()
        } catch {
            // 실패 시점에 비로소 빨간 실패 말풍선을 영속화해서 재전송/삭제 UX 가 가능하게 한다.
            try? insertFailedEntity(
                content: payloadContent,
                files: uploadedPaths,
                modelContext: modelContext
            )
            message = Self.makeErrorMessage(from: error, fallbackMessage: "메시지를 보내지 못했습니다.")
        }
    }

    // 실패 말풍선을 그대로 둔 채 조용히 REST 재시도. 성공하면 실패 엔티티를 지우고 서버 응답으로 교체.
    // 실패 시에는 화면 변화 없음(사용자가 다시 누르면 또 시도). 중복 탭은 retryingMessageIds 로 막는다.
    func retry(messageId: String, modelContext: ModelContext) async {
        guard let entity = findEntity(chatId: messageId, in: modelContext),
              entity.status == .failed,
              !retryingMessageIds.contains(messageId) else {
            return
        }

        retryingMessageIds.insert(messageId)
        defer { retryingMessageIds.remove(messageId) }

        do {
            let networkManager = try makeNetworkManager()
            let request = ChatSendRequestDTO(
                content: entity.content,
                files: entity.files.isEmpty ? nil : entity.files
            )
            let response: ChatResponseDTO = try await networkManager.request(
                ChatRouter.send(roomId: roomId, request: request)
            )
            modelContext.delete(entity)
            try store([response], in: modelContext)
            messages = try cachedMessages(in: modelContext)
            markLastReadIfPossible()
        } catch {
            // 재시도 실패는 조용히 무시한다. 실패 말풍선이 그대로 남아 있어 사용자가 다시 누를 수 있다.
        }
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
            // 소켓 일반 에러는 빨간 토스트로 띄우지 않는다. 연결 상태는 NetworkMonitor 배너가
            // 단일 소스로 표현하고, 토스트는 사용자 행동이 필요한 도메인 에러에만 사용한다.
            service.onStatusChange = { [weak self] status in
                self?.handleSocketStatusChange(status, modelContext: modelContext)
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

        // .sending 상태는 더 이상 새로 만들지 않지만, 과거 테스트로 캐시에 남아 있을 수 있어 제외한다.
        return try modelContext.fetch(descriptor)
            .filter { $0.status != .sending }
            .map(\.displayMessage)
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

// MARK: - 라이프사이클 / 동기화
// type_body_length 룰을 피하기 위해 핵심 클래스 본문 밖으로 분리한다.
// 같은 파일 안에 있어 private 상태/메서드에 그대로 접근할 수 있다.
extension ChatRoomViewModel {
    // 앱이 백그라운드에서 다시 활성화되었을 때 호출. 끊겨 있던 소켓을 다시 붙이고
    // 백그라운드 동안 받지 못한 메시지를 REST 로 보강한다.
    func handleAppActive(modelContext: ModelContext) {
        if socketService == nil {
            connectSocket(modelContext: modelContext)
        }
        Task { await syncMissedMessages(modelContext: modelContext) }
    }

    // 앱이 백그라운드로 들어갈 때 호출. 자원 절약과 stale 소켓 방지를 위해 끊는다.
    // 진짜 화면을 떠나는 onDisappear 와 같은 함수를 재사용한다.
    func handleAppBackground() {
        disconnectSocket()
    }

    // 네트워크가 false → true 로 회복되었을 때 호출.
    // Socket.IO 의 자동 재연결은 만료된 Authorization 헤더를 재사용해 무한 reconnect 루프에
    // 빠질 수 있다. 안전하게 기존 소켓을 폐기하고 현재 토큰으로 새 인스턴스를 만든다.
    func handleNetworkRestored(modelContext: ModelContext) {
        if socketService != nil {
            disconnectSocket()
        }
        connectSocket(modelContext: modelContext)
        Task { await syncMissedMessages(modelContext: modelContext) }
    }

    // 네트워크 또는 소켓 복구 후 마지막으로 받은 sent 메시지 이후의 메시지를 보강한다.
    // 트리거가 동시에 여러 개 발사되어도 한 번만 실제로 호출되도록 idempotent + 짧은 디바운스.
    func syncMissedMessages(modelContext: ModelContext) async {
        if isSyncing {
            return
        }

        if let lastSync = lastSyncAt, Date().timeIntervalSince(lastSync) < 0.5 {
            return
        }

        isSyncing = true
        lastSyncAt = Date()
        defer {
            isSyncing = false
        }

        guard let cursor = lastSentMessage?.dto.createdAt else {
            // 캐시가 비어 있으면 처음부터 가져오는 일반 로드로 폴백.
            await loadMessages(modelContext: modelContext)
            return
        }

        do {
            let networkManager = try makeNetworkManager()
            let query = ChatMessageListQuery(roomId: roomId, next: cursor)
            let response: ChatListResponseDTO = try await networkManager.request(ChatRouter.messages(query))
            try store(response.data, in: modelContext)
            messages = try cachedMessages(in: modelContext)
            markLastReadIfPossible()
        } catch {
            // 동기화 실패는 토스트로 띄우지 않는다. 다음 트리거에서 다시 시도된다.
        }
    }
}

private extension ChatRoomViewModel {
    static func makeFailedMessageId() -> String {
        "failed-" + UUID().uuidString
    }

    func handleSocketStatusChange(
        _ status: ChatSocketService.ConnectionStatus,
        modelContext: ModelContext
    ) {
        switch status {
        case .connected:
            NetworkMonitor.shared.update(socketStatus: .connected)
            // 잔여 빨간 토스트(과거 connection 에러 등)는 연결이 회복되면 의미가 없으니 비운다.
            message = nil
            // disconnect 를 한 번이라도 거친 뒤 다시 connect 된 경우만 재연결로 보고
            // 놓친 메시지 동기화를 트리거한다. 첫 연결은 .task 에서 이미 loadMessages 를 했음.
            if hasBeenDisconnectedSinceConnect {
                hasBeenDisconnectedSinceConnect = false
                Task { await syncMissedMessages(modelContext: modelContext) }
            }
        case .connecting:
            NetworkMonitor.shared.update(socketStatus: .connecting)
        case .disconnected:
            NetworkMonitor.shared.update(socketStatus: .disconnected)
            hasBeenDisconnectedSinceConnect = true
        }
    }

    static let localDateFormatter: ISO8601DateFormatter = {
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

    // 전송 실패 시점에 호출. 사용자 입력을 영속화한 실패 말풍선을 생성한다.
    // chatId 는 "failed-{UUID}" 로 두어 서버 chatId 와 충돌하지 않게 한다.
    func insertFailedEntity(
        content: String,
        files: [String],
        modelContext: ModelContext
    ) throws {
        let nowString = Self.localDateFormatter.string(from: Date())
        let entity = ChatMessageEntity(
            pendingId: Self.makeFailedMessageId(),
            roomId: roomId,
            content: content,
            files: files,
            senderId: currentUserId ?? "",
            senderNick: "",
            senderProfileImage: nil,
            senderIntroduction: nil,
            createdAt: nowString
        )
        entity.setStatus(.failed)
        modelContext.insert(entity)
        try modelContext.save()
        messages = try cachedMessages(in: modelContext)
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
