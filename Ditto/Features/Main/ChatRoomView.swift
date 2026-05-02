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

    let opponentNick: String
    private let authManager: any AuthManaging
    @State private var viewModel: ChatRoomViewModel
    @State private var composingText = ""
    @State private var pickerSelection: [PhotosPickerItem] = []
    @State private var isPresentingPhotosPicker = false
    @State private var isPresentingFileImporter = false
    @State private var presentedMedia: ChatMediaPresentation?

    init(roomId: String, opponentNick: String, authManager: any AuthManaging) {
        self.opponentNick = opponentNick
        self.authManager = authManager
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
        .onChange(of: pickerSelection) { _, items in
            handlePickerChange(items)
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
                                opponentNick: opponentNick,
                                authManager: authManager
                            ) { presentedMedia = $0 }
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
