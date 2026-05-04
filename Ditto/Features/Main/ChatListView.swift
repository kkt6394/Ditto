//
//  ChatListView.swift
//  Ditto
//
//  Created by 김기태 on 4/30/26.
//

import Observation
import SwiftUI

struct ChatListView: View {
    private let authManager: any AuthManaging
    private let onSelectRoom: (String, String) -> Void

    @State private var viewModel: ChatListViewModel

    init(
        authManager: any AuthManaging,
        onSelectRoom: @escaping (String, String) -> Void
    ) {
        self.authManager = authManager
        self.onSelectRoom = onSelectRoom
        _viewModel = State(initialValue: ChatListViewModel(authManager: authManager))
    }

    var body: some View {
        VStack(spacing: 0) {
            MainTopBar()
                .padding(.horizontal, 20)
                .padding(.top, 12)

            HStack {
                Text("채팅")
                    .font(MainFont.pretendard(.bold, size: 24))
                    .foregroundStyle(MainScreenPalette.textPrimary)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 8)

            content
        }
        .background(MainScreenPalette.background.ignoresSafeArea())
        .task(id: ChatPresence.shared.listRefreshTick) {
            // 첫 진입 + 채팅 푸시 도착 + 채팅방에서 돌아왔을 때마다 자동 재로드한다.
            await viewModel.load()
        }
        .refreshable {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.rooms.isEmpty {
            loadingState
        } else if viewModel.rooms.isEmpty {
            emptyState
        } else {
            roomList
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
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(MainScreenPalette.primaryBlue)

            Text(viewModel.message ?? "아직 채팅방이 없습니다.")
                .font(MainScreenTypography.sectionTitle)
                .foregroundStyle(MainScreenPalette.textPrimary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxHeight: .infinity)
    }

    private var roomList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                if let message = viewModel.message {
                    Text(message)
                        .font(MainScreenTypography.timestamp)
                        .foregroundStyle(Color(red: 0.72, green: 0.18, blue: 0.14))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 6)
                }

                ForEach(viewModel.rooms, id: \.roomId) { room in
                    let opponent = viewModel.opponent(for: room)

                    Button {
                        onSelectRoom(room.roomId, opponent?.nick ?? "알 수 없음")
                    } label: {
                        ChatListRow(
                            room: room,
                            opponentNick: opponent?.nick ?? "알 수 없음",
                            hasUnread: viewModel.unreadIndicators.contains(room.roomId),
                            unreadCount: viewModel.unreadCounts[room.roomId]
                        )
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .overlay(MainScreenPalette.border)
                        .padding(.leading, 76)
                }
            }
            .padding(.bottom, 100)
        }
    }
}

@MainActor
@Observable
final class ChatListViewModel {
    private(set) var rooms: [ChatRoomResponseDTO] = []
    private(set) var isLoading = false
    private(set) var message: String?
    private(set) var myUserId: String?
    private(set) var unreadIndicators: Set<String> = []
    private(set) var unreadCounts: [String: Int] = [:]

    private let authManager: any AuthManaging
    private let readStateStore: ChatReadStateStore

    init(
        authManager: any AuthManaging,
        readStateStore: ChatReadStateStore = ChatReadStateStore()
    ) {
        self.authManager = authManager
        self.readStateStore = readStateStore
    }

    func load() async {
        isLoading = true
        message = nil
        defer {
            isLoading = false
        }

        do {
            let networkManager = try makeNetworkManager()

            // 내 ID 확인 실패는 치명적이지 않으므로 별도로 처리한다.
            if let myInfo: MyInfoResponseDTO = try? await networkManager.request(UserRouter.myProfile) {
                myUserId = myInfo.userId
            }

            let response: ChatRoomListResponseDTO = try await networkManager.request(ChatRouter.rooms)
            let sortedRooms = response.data.sorted { lhs, rhs in
                let lTime = lhs.lastChat?.createdAt ?? lhs.updatedAt
                let rTime = rhs.lastChat?.createdAt ?? rhs.updatedAt
                return lTime > rTime
            }
            rooms = sortedRooms

            // 1단계: 로컬 lastReadAt 비교만으로 안 읽음 여부를 즉시 판정해 dot을 띄운다.
            let fetchTargets = identifyUnreadRooms(sortedRooms)

            // 2단계: 안 읽은 방만 메시지 API를 추가 호출해 정확한 카운트로 dot을 숫자 뱃지로 교체한다.
            await fetchUnreadCounts(targets: fetchTargets, networkManager: networkManager)
        } catch {
            message = Self.makeErrorMessage(from: error)
        }
    }

    func opponent(for room: ChatRoomResponseDTO) -> UserInfoResponseDTO? {
        if let myUserId {
            return room.participants.first { $0.userId != myUserId }
        }

        return room.participants.first
    }

    private struct UnreadFetchTarget {
        let roomId: String
        let lastReadAt: String?
    }

    private func identifyUnreadRooms(_ rooms: [ChatRoomResponseDTO]) -> [UnreadFetchTarget] {
        var indicators: Set<String> = []
        var targets: [UnreadFetchTarget] = []

        for room in rooms {
            guard let lastChat = room.lastChat else {
                continue
            }

            // 본인이 마지막으로 보낸 메시지면 안 읽음에 해당하지 않는다.
            if let myUserId, lastChat.sender.userId == myUserId {
                continue
            }

            let lastReadAt = readStateStore.lastReadAt(roomId: room.roomId)
            if let lastReadAt, lastChat.createdAt <= lastReadAt {
                continue
            }

            indicators.insert(room.roomId)
            targets.append(UnreadFetchTarget(roomId: room.roomId, lastReadAt: lastReadAt))
        }

        unreadIndicators = indicators
        unreadCounts = [:]
        return targets
    }

    private func fetchUnreadCounts(
        targets: [UnreadFetchTarget],
        networkManager: any NetworkManaging
    ) async {
        for target in targets {
            do {
                let query = ChatMessageListQuery(roomId: target.roomId, next: target.lastReadAt)
                let response: ChatListResponseDTO = try await networkManager.request(ChatRouter.messages(query))
                unreadCounts[target.roomId] = response.data.count
            } catch {
                // 카운트 호출이 실패해도 dot 인디케이터는 유지된다.
                continue
            }
        }
    }

    private func makeNetworkManager() throws -> any NetworkManaging {
        let configuration = try AppConfiguration()
        return NetworkManager(configuration: configuration, authManager: authManager)
    }

    private static func makeErrorMessage(from error: Error) -> String {
        NetworkErrorMapper.userMessage(from: error, fallback: "채팅 목록을 불러오지 못했습니다.")
    }
}

private struct ChatListRow: View {
    let room: ChatRoomResponseDTO
    let opponentNick: String
    let hasUnread: Bool
    let unreadCount: Int?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(MainScreenPalette.textMuted)
                .frame(width: 48, height: 48)
                .padding(.leading, 16)

            VStack(alignment: .leading, spacing: 4) {
                Text(opponentNick)
                    .font(MainScreenTypography.author)
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .lineLimit(1)

                Text(lastMessageText)
                    .font(MainScreenTypography.body)
                    .foregroundStyle(MainScreenPalette.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(formattedTime)
                    .font(MainScreenTypography.timestamp)
                    .foregroundStyle(MainScreenPalette.textSecondary)

                unreadBadge
            }
            .padding(.trailing, 16)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(MainScreenPalette.surface)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var unreadBadge: some View {
        let badgeColor = Color(red: 0.92, green: 0.27, blue: 0.27)

        if let unreadCount, unreadCount > 0 {
            Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                .font(MainScreenTypography.timestamp)
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(badgeColor, in: Capsule())
        } else if hasUnread {
            // 카운트 도착 전 또는 카운트 호출 실패 시 fallback dot.
            Circle()
                .fill(badgeColor)
                .frame(width: 9, height: 9)
        }
    }

    private var lastMessageText: String {
        guard let chat = room.lastChat else {
            return "대화를 시작해 보세요."
        }

        if !chat.content.isEmpty {
            return chat.content
        }

        if !chat.files.isEmpty {
            return "사진을 보냈습니다."
        }

        return "대화를 시작해 보세요."
    }

    private var formattedTime: String {
        let raw = room.lastChat?.createdAt ?? room.updatedAt

        guard let date = Self.dateFormatter.date(from: raw)
            ?? Self.fallbackDateFormatter.date(from: raw) else {
            return ""
        }

        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return Self.timeFormatter.string(from: date)
        }

        if calendar.isDateInYesterday(date) {
            return "어제"
        }

        return Self.monthDayFormatter.string(from: date)
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

    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M/d"
        return formatter
    }()
}
