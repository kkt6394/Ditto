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
        .task(id: ChatPresence.shared.pushReceivedTick) {
            // 첫 진입 시 1회 + 채팅 푸시 도착 시마다 자동 재로드한다.
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
                        ChatListRow(room: room, opponentNick: opponent?.nick ?? "알 수 없음")
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

    private let authManager: any AuthManaging

    init(authManager: any AuthManaging) {
        self.authManager = authManager
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
            rooms = response.data.sorted { lhs, rhs in
                let lTime = lhs.lastChat?.createdAt ?? lhs.updatedAt
                let rTime = rhs.lastChat?.createdAt ?? rhs.updatedAt
                return lTime > rTime
            }
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

    private func makeNetworkManager() throws -> any NetworkManaging {
        let configuration = try AppConfiguration()
        return NetworkManager(configuration: configuration, authManager: authManager)
    }

    private static func makeErrorMessage(from error: Error) -> String {
        switch error {
        case let error as NetworkError:
            switch error {
            case .missingAuthenticationToken:
                return "로그인이 필요합니다."
            case .statusCode(_, let message, _):
                return message ?? "채팅 목록을 불러오지 못했습니다."
            case .requestFailed:
                return "네트워크 연결을 확인해 주세요."
            default:
                return "채팅 목록을 불러오지 못했습니다."
            }
        case AppConfigurationError.missingValue, AppConfigurationError.invalidURL:
            return "API 설정값을 확인해 주세요."
        default:
            return "채팅 목록을 불러오지 못했습니다."
        }
    }
}

private struct ChatListRow: View {
    let room: ChatRoomResponseDTO
    let opponentNick: String

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

            Text(formattedTime)
                .font(MainScreenTypography.timestamp)
                .foregroundStyle(MainScreenPalette.textSecondary)
                .padding(.trailing, 16)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(MainScreenPalette.surface)
        .contentShape(Rectangle())
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
