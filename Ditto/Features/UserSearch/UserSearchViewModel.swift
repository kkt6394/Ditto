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
        isSearching = false
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
