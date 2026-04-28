//
//  ChatRoomView.swift
//  Ditto
//
//  Created by Codex on 4/28/26.
//

import Observation
import SwiftUI

struct ChatRoomView: View {
    @Environment(\.dismiss) private var dismiss

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

            composer
        }
        .background(MainScreenPalette.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: viewModel.roomId) {
            await viewModel.loadMessages()
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
                            ChatBubble(message: message)
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
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("메시지 입력", text: $composingText, axis: .vertical)
                .font(MainScreenTypography.body)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(MainScreenPalette.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button {
                let text = composingText
                composingText = ""

                Task {
                    await viewModel.send(text)
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

    init(roomId: String, authManager: any AuthManaging) {
        self.roomId = roomId
        self.authManager = authManager
    }

    func loadMessages() async {
        isLoading = true
        message = nil
        defer {
            isLoading = false
        }

        do {
            let networkManager = try makeNetworkManager()
            let query = ChatMessageListQuery(roomId: roomId, next: nil)
            let response: ChatListResponseDTO = try await networkManager.request(ChatRouter.messages(query))
            messages = response.data
        } catch {
            message = Self.makeErrorMessage(from: error, fallbackMessage: "채팅 내용을 불러오지 못했습니다.")
        }
    }

    func send(_ content: String) async {
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
            messages.append(response)
        } catch {
            message = Self.makeErrorMessage(from: error, fallbackMessage: "메시지를 보내지 못했습니다.")
        }
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

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(message.sender.nick)
                .font(MainScreenTypography.timestamp)
                .foregroundStyle(MainScreenPalette.textSecondary)

            Text(message.content)
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(MainScreenPalette.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(MainScreenPalette.border, lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
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
