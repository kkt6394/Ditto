//
//  ChatRoomView.swift
//  Ditto
//
//  Created by Codex on 4/28/26.
//

import Observation
import SwiftData
import SwiftUI

struct ChatRoomView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let opponentNick: String
    @State private var viewModel: ChatRoomViewModel
    @State private var composingText = ""

    init(roomId: String, opponentNick: String, authManager: any AuthManaging) {
        self.opponentNick = opponentNick
        _viewModel = State(initialValue: ChatRoomViewModel(roomId: roomId, authManager: authManager))
    }

    var body: some View {
        VStack(spacing: 0) {
            navigationBar

            if viewModel.isLoading && viewModel.messages.isEmpty {
                ChatStateView(title: "채팅 내용을 불러오는 중입니다.", systemName: "arrow.clockwise")
                    .frame(maxHeight: .infinity)
            } else {
                messageList
            }

            if let message = viewModel.message {
                Text(message)
                    .font(MainScreenTypography.timestamp)
                    .foregroundStyle(Color(red: 0.72, green: 0.18, blue: 0.14))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            }
        }
        .background(MainScreenPalette.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composer
        }
        .task(id: viewModel.roomId) {
            await viewModel.start(modelContext: modelContext)
        }
        .onAppear {
            ChatPresence.shared.activeRoomId = viewModel.roomId
        }
        .onDisappear {
            viewModel.disconnectSocket()
            ChatPresence.shared.activeRoomId = nil
        }
    }

    private var navigationBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(opponentNick)
                .font(MainFont.pretendard(.bold, size: 16))
                .foregroundStyle(MainScreenPalette.textPrimary)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 4)
        .frame(height: 44)
        .background(MainScreenPalette.surface)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if viewModel.messages.isEmpty {
                        ChatStateView(title: "아직 메시지가 없습니다.", systemName: "bubble.left.and.bubble.right")
                            .padding(.top, 80)
                    } else {
                        ForEach(viewModel.messages, id: \.chatId) { message in
                            ChatBubble(
                                message: message,
                                isOutgoing: viewModel.isOutgoing(message, opponentNick: opponentNick),
                                opponentNick: opponentNick
                            )
                                .id(message.chatId)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                guard let lastId = viewModel.messages.last?.chatId else {
                    return
                }

                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("메시지 입력", text: $composingText, axis: .vertical)
                .font(MainScreenTypography.body)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(MainScreenPalette.border, lineWidth: 1)
                )

            Button {
                let text = composingText
                composingText = ""

                Task {
                    await viewModel.send(text, modelContext: modelContext)
                }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(MainScreenPalette.primaryBlue, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(composingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSending)
            .opacity(composingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(MainScreenPalette.surface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(MainScreenPalette.border)
                .frame(height: 1)
        }
    }
}

@MainActor
@Observable
final class ChatRoomViewModel {
    let roomId: String
    private(set) var messages: [ChatResponseDTO] = []
    private(set) var isLoading = false
    private(set) var isSending = false
    private(set) var message: String?

    private let authManager: any AuthManaging
    private let readStateStore: ChatReadStateStore
    private var currentUserId: String?
    private var socketService: ChatSocketService?

    init(roomId: String, authManager: any AuthManaging, readStateStore: ChatReadStateStore = ChatReadStateStore()) {
        self.roomId = roomId
        self.authManager = authManager
        self.readStateStore = readStateStore
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

    private func markLastReadIfPossible() {
        guard let lastCreatedAt = messages.last?.createdAt else {
            return
        }

        readStateStore.setLastReadAt(lastCreatedAt, roomId: roomId)
    }

    func isOutgoing(_ chatMessage: ChatResponseDTO, opponentNick: String) -> Bool {
        if let currentUserId {
            return chatMessage.sender.userId == currentUserId
        }

        return chatMessage.sender.nick != opponentNick
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
            let query = ChatMessageListQuery(roomId: roomId, next: messages.last?.createdAt)
            let response: ChatListResponseDTO = try await networkManager.request(ChatRouter.messages(query))
            try store(response.data, in: modelContext)
            messages = try cachedMessages(in: modelContext)
            markLastReadIfPossible()
        } catch {
            message = Self.makeErrorMessage(from: error, fallbackMessage: "채팅 내용을 불러오지 못했습니다.")
        }
    }

    func send(_ content: String, modelContext: ModelContext) async {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedContent.isEmpty else {
            return
        }

        isSending = true
        message = nil
        defer {
            isSending = false
        }

        do {
            let networkManager = try makeNetworkManager()
            let request = ChatSendRequestDTO(content: trimmedContent, files: nil)
            let response: ChatResponseDTO = try await networkManager.request(
                ChatRouter.send(roomId: roomId, request: request)
            )
            try store([response], in: modelContext)
            messages = try cachedMessages(in: modelContext)
            markLastReadIfPossible()
        } catch {
            message = Self.makeErrorMessage(from: error, fallbackMessage: "메시지를 보내지 못했습니다.")
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

    private func cachedMessages(in modelContext: ModelContext) throws -> [ChatResponseDTO] {
        let descriptor = FetchDescriptor<ChatMessageEntity>(
            predicate: #Predicate { message in
                message.roomId == roomId
            },
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )

        return try modelContext.fetch(descriptor).map(\.dto)
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

    private static func makeErrorMessage(from error: Error, fallbackMessage: String) -> String {
        switch error {
        case let error as NetworkError:
            switch error {
            case .missingAuthenticationToken:
                return "로그인이 필요합니다."
            case .statusCode(_, let message, _):
                return message ?? fallbackMessage
            case .requestFailed:
                return "네트워크 연결을 확인해 주세요."
            default:
                return fallbackMessage
            }
        case AppConfigurationError.missingValue, AppConfigurationError.invalidURL:
            return "API 설정값을 확인해 주세요."
        default:
            return fallbackMessage
        }
    }
}

private struct ChatBubble: View {
    let message: ChatResponseDTO
    let isOutgoing: Bool
    let opponentNick: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isOutgoing {
                Spacer(minLength: 52)
                timeText
                bubble
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.sender.nick.isEmpty ? opponentNick : message.sender.nick)
                        .font(MainScreenTypography.timestamp)
                        .foregroundStyle(MainScreenPalette.textSecondary)

                    HStack(alignment: .bottom, spacing: 6) {
                        bubble
                        timeText
                    }
                }
                Spacer(minLength: 52)
            }
        }
        .frame(maxWidth: .infinity, alignment: isOutgoing ? .trailing : .leading)
    }

    private var bubble: some View {
        Text(message.content)
            .font(MainScreenTypography.body)
            .foregroundStyle(isOutgoing ? .white : MainScreenPalette.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: 260, alignment: .leading)
            .background(bubbleColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isOutgoing ? Color.clear : MainScreenPalette.border, lineWidth: 1)
            )
    }

    private var timeText: some View {
        Text(formattedTime)
            .font(MainScreenTypography.timestamp)
            .foregroundStyle(MainScreenPalette.textSecondary)
            .lineLimit(1)
            .padding(.bottom, 2)
    }

    private var bubbleColor: Color {
        isOutgoing ? MainScreenPalette.primaryBlue : MainScreenPalette.surface
    }

    private var formattedTime: String {
        guard let date = Self.dateFormatter.date(from: message.createdAt)
            ?? Self.fallbackDateFormatter.date(from: message.createdAt) else {
            return ""
        }

        return Self.timeFormatter.string(from: date)
    }

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fallbackDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter
    }()
}

private struct ChatStateView: View {
    let title: String
    let systemName: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(MainScreenPalette.primaryBlue)

            Text(title)
                .font(MainScreenTypography.sectionTitle)
                .foregroundStyle(MainScreenPalette.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
