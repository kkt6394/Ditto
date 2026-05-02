//
//  KeepStore.swift
//  Ditto
//
//  Created by Codex on 5/1/26.
//

import Foundation
import Observation

// 액티비티 좋아요(keep) 상태를 단일 소스로 관리한다.
// 홈/검색/상세/좋아요 탭이 모두 같은 keptActivityIDs와 likedActivities를 바라보게 해
// 어느 화면에서 토글하더라도 다른 화면이 즉시 반영되도록 한다.
@MainActor
@Observable
final class KeepStore {
    private(set) var keptActivityIDs: Set<String> = []
    private(set) var likedActivities: [LikedActivity] = []
    private(set) var isLoadingLikedActivities = false
    private(set) var likedActivitiesMessage: String?
    private(set) var nextCursor: String?

    // 좋아요가 새로 추가되는 순간, 카드 하트가 좋아요 탭 아이콘으로 날아가는 비행 애니메이션을
    // 트리거하기 위한 activityId. 비행이 끝나면 nil로 되돌린다.
    private(set) var pendingFlightID: String?

    // 카드 모델의 isKeep을 KeepStore에 한 번만 시드한다.
    // 이미 등록된 액티비티는 사용자의 최신 토글이 우선이므로 덮어쓰지 않는다.
    @ObservationIgnored private var registeredInitialIDs: Set<String> = []

    private let networkManagerProvider: @MainActor () throws -> any NetworkManaging
    private let configurationProvider: @MainActor () throws -> AppConfiguration
    private let authManager: any AuthManaging

    convenience init(authManager: any AuthManaging) {
        self.init(
            networkManagerProvider: {
                let configuration = try AppConfiguration()
                return NetworkManager(configuration: configuration, authManager: authManager)
            },
            configurationProvider: {
                try AppConfiguration()
            },
            authManager: authManager
        )
    }

    init(
        networkManagerProvider: @escaping @MainActor () throws -> any NetworkManaging,
        configurationProvider: @escaping @MainActor () throws -> AppConfiguration,
        authManager: any AuthManaging
    ) {
        self.networkManagerProvider = networkManagerProvider
        self.configurationProvider = configurationProvider
        self.authManager = authManager
    }

    func isKept(_ activityId: String) -> Bool {
        keptActivityIDs.contains(activityId)
    }

    // 카드 화면(홈/검색/상세)에서 받은 isKeep 값을 store에 시드한다.
    // 이미 시드되었거나 사용자가 토글한 적 있는 액티비티는 보호하기 위해 덮어쓰지 않는다.
    func registerInitialKeepStatus(activityId: String, isKept: Bool) {
        guard !registeredInitialIDs.contains(activityId) else {
            return
        }
        registeredInitialIDs.insert(activityId)
        if isKept {
            keptActivityIDs.insert(activityId)
        }
    }

    // 좋아요 토글. 낙관적 업데이트 후 실패 시 롤백한다.
    // triggersFlight: 좋아요 탭 아이콘으로 향하는 비행 트랜지션을 시작할지 여부.
    // 탭바가 보이지 않는 상세 화면 같은 곳에서는 false로 전달해 비행이 큐잉되어
    // 뒤늦게 재생되는 것을 막는다.
    func toggleKeep(activityId: String, triggersFlight: Bool = true) async {
        let willKeep = !keptActivityIDs.contains(activityId)
        let snapshot = applyOptimisticToggle(activityId: activityId, willKeep: willKeep)

        // 좋아요 추가 시점에 비행 트랜지션을 즉시 시작해 사용자가 탭의 즉각적 반응을 느끼게 한다.
        if willKeep && triggersFlight {
            pendingFlightID = activityId
        }

        do {
            let networkManager = try networkManagerProvider()
            let request = ActivityKeepRequestDTO(keepStatus: willKeep)
            let response: ActivityKeepResponseDTO = try await networkManager.request(
                ActivityRouter.keep(activityId: activityId, request: request)
            )
            // 서버 응답으로 최종 확정한다.
            if response.keepStatus {
                keptActivityIDs.insert(activityId)
            } else {
                keptActivityIDs.remove(activityId)
                likedActivities.removeAll { $0.id == activityId }
            }
        } catch {
            rollbackOptimisticToggle(activityId: activityId, willKeep: willKeep, snapshot: snapshot)
            if willKeep && pendingFlightID == activityId {
                pendingFlightID = nil
            }
        }
    }

    // 비행 애니메이션이 끝났을 때 호출돼 pendingFlightID를 비운다.
    func finishFlightAnimation(activityId: String) {
        if pendingFlightID == activityId {
            pendingFlightID = nil
        }
    }

    // 좋아요 탭 진입 시 호출. 서버 목록으로 그리드 데이터를 채운다.
    func loadLikedActivities() async {
        isLoadingLikedActivities = true
        likedActivitiesMessage = nil
        defer { isLoadingLikedActivities = false }

        do {
            let networkManager = try networkManagerProvider()
            let configuration = try configurationProvider()
            // 서버 기본값(5)이 너무 작아 좋아요 탭에 일부만 보이는 문제를 막기 위해
            // 한 번에 더 많이 가져온다. 100을 초과하는 경우는 추후 pagination으로 처리한다.
            let query = ActivityKeepListQuery(country: nil, category: nil, next: nil, limit: 100)
            let response: ActivitySummaryListResponseDTO = try await networkManager.request(
                ActivityRouter.myKeeps(query)
            )

            let mapped = response.data.map { dto in
                Self.makeLikedActivity(
                    from: dto,
                    configuration: configuration,
                    accessToken: authManager.tokens?.accessToken
                )
            }

            keptActivityIDs = Set(mapped.map { $0.id })
            likedActivities = mapped
            nextCursor = response.nextCursor.isEmpty ? nil : response.nextCursor
        } catch {
            likedActivitiesMessage = Self.makeErrorMessage(from: error)
        }
    }

    private func applyOptimisticToggle(activityId: String, willKeep: Bool) -> OptimisticSnapshot {
        if willKeep {
            keptActivityIDs.insert(activityId)
            return OptimisticSnapshot(removedItem: nil, removedIndex: nil)
        }

        keptActivityIDs.remove(activityId)
        let index = likedActivities.firstIndex { $0.id == activityId }
        let item = index.map { likedActivities[$0] }
        if let index {
            likedActivities.remove(at: index)
        }
        return OptimisticSnapshot(removedItem: item, removedIndex: index)
    }

    private func rollbackOptimisticToggle(
        activityId: String,
        willKeep: Bool,
        snapshot: OptimisticSnapshot
    ) {
        if willKeep {
            keptActivityIDs.remove(activityId)
            return
        }

        keptActivityIDs.insert(activityId)
        if let item = snapshot.removedItem, let index = snapshot.removedIndex {
            let safeIndex = min(index, likedActivities.count)
            likedActivities.insert(item, at: safeIndex)
        }
    }

    static func makeLikedActivity(
        from response: ActivitySummaryResponseDTO,
        configuration: AppConfiguration,
        accessToken: String?
    ) -> LikedActivity {
        let title = response.title.flatMap { $0.isEmpty ? nil : $0 } ?? "제목 없는 액티비티"
        return LikedActivity(
            id: response.activityId,
            title: title,
            location: ActivityFormatting.makeLocationText(country: response.country),
            priceText: ActivityFormatting.makePriceText(response.price.final),
            imageRequest: ActivityFormatting.makeImageRequest(
                from: ActivityFormatting.firstImageThumbnail(from: response.thumbnails),
                configuration: configuration,
                accessToken: accessToken
            )
        )
    }

    static func makeErrorMessage(from error: Error) -> String {
        switch error {
        case let error as NetworkError:
            return MainViewModel.makeNetworkErrorMessage(
                from: error,
                fallbackMessage: "좋아요 목록을 불러오지 못했습니다."
            )
        case AppConfigurationError.missingValue, AppConfigurationError.invalidURL:
            return "API 설정값을 확인해 주세요."
        default:
            return "좋아요 목록을 불러오지 못했습니다."
        }
    }
}

private struct OptimisticSnapshot {
    let removedItem: LikedActivity?
    let removedIndex: Int?
}

struct LikedActivity: Identifiable, Equatable {
    let id: String
    let title: String
    let location: String
    let priceText: String
    let imageRequest: URLRequest?
}
