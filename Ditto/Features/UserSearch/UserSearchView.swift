//
//  UserSearchView.swift
//  Ditto
//
//  Created by Codex on 5/5/26.
//

import Observation
import SwiftUI

// 닉네임으로 다른 유저를 검색하고, 셀을 누르면 1:1 채팅방을 생성/조회한 뒤 닫힌다.
struct UserSearchView: View {
    @Environment(\.dismiss) private var dismiss

    private let authManager: any AuthManaging
    private let onChatRoomReady: (String, String) -> Void

    @State private var viewModel: UserSearchViewModel
    // 같은 유저를 빠르게 두 번 누른 경우 중복 채팅방 생성 요청을 방지하기 위한 가드.
    @State private var pendingChatOpponentIDs: Set<String> = []

    init(
        authManager: any AuthManaging,
        onChatRoomReady: @escaping (String, String) -> Void
    ) {
        self.authManager = authManager
        self.onChatRoomReady = onChatRoomReady
        _viewModel = State(initialValue: UserSearchViewModel(authManager: authManager))
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            searchField

            content
        }
        .background(MainScreenPalette.background.ignoresSafeArea())
    }

    private var header: some View {
        HStack {
            Text("유저 검색")
                .font(MainFont.pretendard(.bold, size: 20))
                .foregroundStyle(MainScreenPalette.textPrimary)

            Spacer()

            Button {
                viewModel.clear()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .padding(8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(MainScreenPalette.textSecondary)

            TextField("닉네임으로 검색", text: $viewModel.query)
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.search)
                .onSubmit {
                    viewModel.search()
                }

            if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
                    viewModel.search()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(MainScreenPalette.textMuted)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(MainScreenPalette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(MainScreenPalette.border, lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isSearching && viewModel.results.isEmpty {
            loadingState
        } else if let chatStartMessage = viewModel.chatStartMessage {
            errorBanner(message: chatStartMessage)
            resultsList
        } else if let message = viewModel.message {
            errorBanner(message: message)
            resultsList
        } else if viewModel.results.isEmpty {
            emptyState
        } else {
            resultsList
        }
    }

    private var loadingState: some View {
        VStack {
            Spacer()
            ProgressView()
                .tint(MainScreenPalette.primaryBlue)
            Spacer()
        }
        .frame(maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "person.text.rectangle")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(MainScreenPalette.primaryBlue)

            Text(viewModel.query.isEmpty ? "닉네임을 입력해 검색해 보세요." : "일치하는 유저가 없습니다.")
                .font(MainScreenTypography.sectionTitle)
                .foregroundStyle(MainScreenPalette.textPrimary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxHeight: .infinity)
    }

    private func errorBanner(message: String) -> some View {
        Text(message)
            .font(MainScreenTypography.timestamp)
            .foregroundStyle(Color(red: 0.72, green: 0.18, blue: 0.14))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
    }

    private var resultsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.results, id: \.userId) { user in
                    Button {
                        startChat(with: user)
                    } label: {
                        UserSearchRow(
                            user: user,
                            isPending: pendingChatOpponentIDs.contains(user.userId)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(pendingChatOpponentIDs.contains(user.userId))

                    Divider()
                        .overlay(MainScreenPalette.border)
                        .padding(.leading, 76)
                }
            }
            .padding(.bottom, 24)
        }
    }

    private func startChat(with user: UserInfoResponseDTO) {
        let opponentId = user.userId
        let opponentNick = user.nick

        // 같은 유저에 대해 in-flight 요청이 이미 있다면 무시한다.
        guard pendingChatOpponentIDs.insert(opponentId).inserted else {
            return
        }

        Task { @MainActor in
            defer {
                pendingChatOpponentIDs.remove(opponentId)
            }

            guard let room = await viewModel.createChatRoom(opponentId: opponentId) else {
                return
            }

            dismiss()
            onChatRoomReady(room.roomId, opponentNick)
        }
    }
}

private struct UserSearchRow: View {
    let user: UserInfoResponseDTO
    let isPending: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(MainScreenPalette.textMuted)
                .frame(width: 48, height: 48)
                .padding(.leading, 16)

            VStack(alignment: .leading, spacing: 4) {
                Text(user.nick)
                    .font(MainScreenTypography.author)
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .lineLimit(1)

                if let introduction = user.introduction, !introduction.isEmpty {
                    Text(introduction)
                        .font(MainScreenTypography.body)
                        .foregroundStyle(MainScreenPalette.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isPending {
                ProgressView()
                    .tint(MainScreenPalette.primaryBlue)
                    .padding(.trailing, 16)
            } else {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MainScreenPalette.primaryBlue)
                    .padding(.trailing, 16)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(MainScreenPalette.surface)
        .contentShape(Rectangle())
    }
}
