//
//  UserSearchViewModel.swift
//  Ditto
//
//  Created by Codex on 5/4/26.
//

import Foundation
import Observation

// 닉네임으로 사용자를 검색하는 ViewModel.
// 입력 → 디바운스 → 검색 → 결과 표시 흐름은 호출하는 화면이 결정하므로 여기서는 단순 검색 액션만 노출한다.
@MainActor
@Observable
final class UserSearchViewModel {
    var query: String = ""
    private(set) var results: [UserInfoResponseDTO] = []
    private(set) var isSearching = false
    var message: String?
    // 채팅방 생성 시 발생한 에러 메시지. ActivityDetailViewModel과 동일하게 사용자가 볼 수 있도록 노출한다.
    private(set) var chatStartMessage: String?

    private let networkManagerProvider: @MainActor () throws -> any NetworkManaging
    private var currentTask: Task<Void, Never>?

    convenience init(authManager: any AuthManaging) {
        self.init(networkManagerProvider: {
            let configuration = try AppConfiguration()
            return NetworkManager(configuration: configuration, authManager: authManager)
        })
    }

    init(networkManagerProvider: @escaping @MainActor () throws -> any NetworkManaging) {
        self.networkManagerProvider = networkManagerProvider
    }

    /// 새 검색을 시작하고 이전 in-flight 요청은 취소한다.
    func search() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            message = nil
            return
        }

        currentTask?.cancel()
        currentTask = Task { [weak self] in
            await self?.performSearch(nick: trimmed)
        }
    }

    func clear() {
        currentTask?.cancel()
        currentTask = nil
        query = ""
        results = []
        message = nil
        chatStartMessage = nil
        isSearching = false
    }

    /// 상대 유저와의 1:1 채팅방을 생성한다. 이미 존재하는 경우 기존 방을 반환한다.
    /// ActivityDetailViewModel.createChatRoom(opponentId:) 패턴을 그대로 차용한다.
    func createChatRoom(opponentId: String) async -> ChatRoomResponseDTO? {
        chatStartMessage = nil

        do {
            let networkManager = try networkManagerProvider()
            let request = ChatRoomCreateRequestDTO(opponentId: opponentId)
            return try await networkManager.request(ChatRouter.createRoom(request))
        } catch {
            do {
                let networkManager = try networkManagerProvider()
                if let existingRoom = try await existingChatRoom(
                    opponentId: opponentId,
                    networkManager: networkManager
                ) {
                    return existingRoom
                }
            } catch {
                // 새 방 생성 실패 원인이 기존 방인 경우가 있어, 목록 조회 실패보다 원래 오류 메시지를 우선 보여준다.
            }

            chatStartMessage = NetworkErrorMapper.userMessage(
                from: error,
                fallback: "채팅방을 만들지 못했습니다."
            )
            return nil
        }
    }

    private func existingChatRoom(
        opponentId: String,
        networkManager: any NetworkManaging
    ) async throws -> ChatRoomResponseDTO? {
        let response: ChatRoomListResponseDTO = try await networkManager.request(ChatRouter.rooms)

        return response.data.first { room in
            room.participants.contains { participant in
                participant.userId == opponentId
            }
        }
    }

    private func performSearch(nick: String) async {
        isSearching = true
        message = nil
        defer { isSearching = false }

        do {
            let networkManager = try networkManagerProvider()
            let response: UserInfoListResponseDTO = try await networkManager.request(
                UserRouter.search(nick: nick)
            )
            // 응답 사이에 사용자가 입력을 바꿨거나 clear()를 호출했을 수 있어 취소 여부를 다시 확인한다.
            if Task.isCancelled { return }
            results = response.data
        } catch is CancellationError {
            return
        } catch {
            if Task.isCancelled { return }
            message = NetworkErrorMapper.userMessage(from: error, fallback: "사용자 검색에 실패했습니다.")
        }
    }
}
