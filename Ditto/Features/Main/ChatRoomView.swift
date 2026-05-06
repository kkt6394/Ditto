//
//  ChatRoomView.swift
//  Ditto
//
//  Created by Codex on 4/28/26.
//

import Observation
import PhotosUI
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ChatRoomView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    let opponentNick: String
    private let authManager: any AuthManaging
    @State private var viewModel: ChatRoomViewModel
    @State private var networkMonitor = NetworkMonitor.shared
    @State private var composingText = ""
    @State private var pickerSelection: [PhotosPickerItem] = []
    @State private var isPresentingPhotosPicker = false
    @State private var isPresentingFileImporter = false
    @State private var presentedMedia: ChatMediaPresentation?
    @State private var failedMessageId: String?

    init(roomId: String, opponentNick: String, authManager: any AuthManaging) {
        self.opponentNick = opponentNick
        self.authManager = authManager
        _viewModel = State(initialValue: ChatRoomViewModel(roomId: roomId, authManager: authManager))
    }

    var body: some View {
        VStack(spacing: 0) {
            navigationBar

            if networkMonitor.bannerState != .hidden {
                ChatRoomNetworkBanner(state: networkMonitor.bannerState)
            }

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
        .animation(.easeInOut(duration: 0.2), value: networkMonitor.bannerState)
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
        .onChange(of: pickerSelection) { _, items in
            handlePickerChange(items)
        }
        .onChange(of: scenePhase) { _, newPhase in
            // 채팅방에 머무는 동안 백그라운드↔포그라운드 전이를 ViewModel 에 위임한다.
            // .inactive 는 잠깐 거치는 단계라 무시한다.
            switch newPhase {
            case .active:
                viewModel.handleAppActive(modelContext: modelContext)
            case .background:
                viewModel.handleAppBackground()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        .onChange(of: networkMonitor.isOnline) { wasOnline, isOnline in
            // 오프라인 → 온라인 전이에서만 소켓을 강제로 새로 만든다.
            // Socket.IO 의 stale 토큰 reconnect 루프를 끊기 위함.
            guard !wasOnline, isOnline else { return }
            viewModel.handleNetworkRestored(modelContext: modelContext)
        }
        .photosPicker(
            isPresented: $isPresentingPhotosPicker,
            selection: $pickerSelection,
            maxSelectionCount: viewModel.remainingAttachmentSlots,
            matching: .images,
            photoLibrary: .shared()
        )
        .fileImporter(
            isPresented: $isPresentingFileImporter,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: true,
            onCompletion: handleFileImporter
        )
        .fullScreenCover(item: $presentedMedia) { presentation in
            ChatMediaFullScreen(media: presentation, authManager: authManager)
        }
        .confirmationDialog(
            "이 메시지를 어떻게 할까요?",
            isPresented: Binding(
                get: { failedMessageId != nil },
                set: { newValue in if !newValue { failedMessageId = nil } }
            ),
            titleVisibility: .visible,
            presenting: failedMessageId
        ) { messageId in
            Button("재전송") {
                failedMessageId = nil
                Task {
                    await viewModel.retry(messageId: messageId, modelContext: modelContext)
                }
            }
            Button("삭제", role: .destructive) {
                failedMessageId = nil
                viewModel.discardFailed(messageId: messageId, modelContext: modelContext)
            }
            Button("취소", role: .cancel) {
                failedMessageId = nil
            }
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
                        ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, display in
                            ChatBubble(
                                message: display.dto,
                                isOutgoing: viewModel.isOutgoing(display.dto, opponentNick: opponentNick),
                                opponentNick: opponentNick,
                                authManager: authManager,
                                status: display.status,
                                showTime: shouldShowTime(at: index),
                                showSenderName: shouldShowSenderName(at: index),
                                onSelectMedia: { presentedMedia = $0 },
                                onTapFailed: { failedMessageId = display.id }
                            )
                                .id(display.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                guard let lastId = viewModel.messages.last?.id else {
                    return
                }

                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var composer: some View {
        VStack(spacing: 0) {
            if !viewModel.attachments.isEmpty {
                ChatAttachmentPreviewStrip(
                    attachments: viewModel.attachments
                ) { viewModel.removeAttachment($0) }
            }

            HStack(alignment: .bottom, spacing: 8) {
                attachmentMenu

                TextField("메시지 입력", text: $composingText, axis: .vertical)
                    .font(MainScreenTypography.body)
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .tint(MainScreenPalette.primaryBlue)
                    .lineLimit(1...4)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(MainScreenPalette.border, lineWidth: 1)
                    )

                sendButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(MainScreenPalette.surface)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(MainScreenPalette.border)
                .frame(height: 1)
        }
    }

    private var attachmentMenu: some View {
        // 사진과 PDF는 시스템 시트가 다르기 때문에 Menu에서 어떤 종류를 첨부할지 먼저 고른다.
        Menu {
            Button {
                isPresentingPhotosPicker = true
            } label: {
                Label("사진", systemImage: "photo")
            }

            Button {
                isPresentingFileImporter = true
            } label: {
                Label("PDF 파일", systemImage: "doc.richtext")
            }
        } label: {
            attachmentButtonLabel
        }
        .disabled(viewModel.remainingAttachmentSlots == 0)
        .opacity(viewModel.remainingAttachmentSlots == 0 ? 0.45 : 1)
    }

    private var attachmentButtonLabel: some View {
        Image(systemName: "paperclip")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(MainScreenPalette.primaryBlue)
            .frame(width: 42, height: 42)
            .background(MainScreenPalette.primaryBlueSoft, in: Circle())
    }

    private var sendButton: some View {
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
        .disabled(!viewModel.canSend(text: composingText))
        .opacity(viewModel.canSend(text: composingText) ? 1 : 0.45)
    }

    private func handlePickerChange(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }

        Task {
            var inputs: [ChatAttachmentInput] = []
            for item in items {
                guard let raw = try? await item.loadTransferable(type: Data.self) else { continue }
                inputs.append(.image(raw: raw))
            }
            viewModel.appendAttachments(inputs)
            pickerSelection = []
        }
    }

    private func handleFileImporter(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }

        var inputs: [ChatAttachmentInput] = []
        for url in urls {
            let didStartAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if didStartAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            guard let data = try? Data(contentsOf: url) else { continue }
            inputs.append(.pdf(filename: url.lastPathComponent, data: data))
        }
        viewModel.appendAttachments(inputs)
    }
}

// 메시지 그룹핑 헬퍼 — 본문 밖으로 빼서 type_body_length 룰을 통과한다.
extension ChatRoomView {
    // 같은 발신자 연속 그룹의 첫 메시지에만 닉네임을 표시한다 (incoming 한정).
    fileprivate func shouldShowSenderName(at index: Int) -> Bool {
        let messages = viewModel.messages
        guard messages.indices.contains(index) else { return false }

        let previousIndex = index - 1
        guard messages.indices.contains(previousIndex) else {
            return true
        }

        let current = messages[index].dto
        let previous = messages[previousIndex].dto
        return current.sender.userId != previous.sender.userId
    }

    // 같은 분 + 같은 발신자가 연속될 때 그룹의 마지막 메시지에만 시간을 표시한다.
    // 마지막 메시지(다음이 없음)는 항상 시간을 표시한다.
    fileprivate func shouldShowTime(at index: Int) -> Bool {
        let messages = viewModel.messages
        guard messages.indices.contains(index) else { return false }

        let nextIndex = index + 1
        guard messages.indices.contains(nextIndex) else {
            return true
        }

        let current = messages[index].dto
        let next = messages[nextIndex].dto

        if current.sender.userId != next.sender.userId {
            return true
        }

        return !ChatTimestampHelper.isSameMinute(current.createdAt, next.createdAt)
    }
}

private enum ChatTimestampHelper {
    static func isSameMinute(_ lhs: String, _ rhs: String) -> Bool {
        guard let date1 = parse(lhs), let date2 = parse(rhs) else {
            return false
        }

        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute]
        let lhsComponents = Calendar.current.dateComponents(components, from: date1)
        let rhsComponents = Calendar.current.dateComponents(components, from: date2)
        return lhsComponents == rhsComponents
    }

    private static func parse(_ string: String) -> Date? {
        isoFractional.date(from: string) ?? isoBasic.date(from: string)
    }

    private static let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoBasic: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
