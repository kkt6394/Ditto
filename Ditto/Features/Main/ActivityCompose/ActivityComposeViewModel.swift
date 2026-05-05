//
//  ActivityComposeViewModel.swift
//  Ditto
//
//  Created by Codex on 5/5/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class ActivityComposeViewModel {
    let mode: ActivityComposeMode

    // 기본 정보
    var title: String = ""
    var country: String = ""
    var category: String = ""
    var descriptionText: String = ""

    // 위치
    var latitude: Double?
    var longitude: Double?

    // 일정
    var startDate: Date?
    var endDate: Date?
    var schedule: [ActivityComposeScheduleDraft] = []

    // 가격/포인트/제약
    var originalPrice: Double?
    var finalPrice: Double?
    var pointReward: Double?
    var minHeight: Double?
    var minAge: Double?
    var maxParticipants: Double?

    // 광고/태그
    var isAdvertisement: Bool = false
    var tagsText: String = ""

    // 미디어
    private(set) var attachments: [ActivityComposeAttachment] = []
    private(set) var existingThumbnails: [ActivityComposeExistingThumbnail] = []

    // 폼 상태
    private(set) var isPrefilling = false
    private(set) var isSubmitting = false
    private(set) var formMessage: String?
    private(set) var didSubmitSuccessfully = false

    // 검색·메인탭과 동일한 옵션을 그대로 사용한다.
    let countryOptions: [String]
    let categoryOptions: [String]

    private let networkManagerProvider: @MainActor () throws -> any NetworkManaging
    private let authManager: (any AuthManaging)?

    convenience init(mode: ActivityComposeMode, authManager: any AuthManaging) {
        self.init(
            mode: mode,
            networkManagerProvider: {
                let configuration = try AppConfiguration()
                return NetworkManager(configuration: configuration, authManager: authManager)
            },
            authManager: authManager
        )
    }

    init(
        mode: ActivityComposeMode,
        networkManagerProvider: @escaping @MainActor () throws -> any NetworkManaging,
        authManager: (any AuthManaging)?
    ) {
        self.mode = mode
        self.networkManagerProvider = networkManagerProvider
        self.authManager = authManager
        self.countryOptions = MainCountryFilter.samples.map { $0.name }
        self.categoryOptions = MainCategoryFilter.samples
            .filter { $0.id != "all" }
            .map { $0.title }
    }

    // 제출 가능 여부. 필수 필드(7번 결정사항)가 모두 채워져야 true.
    var canSubmit: Bool {
        guard !isSubmitting else { return false }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard !country.isEmpty, !category.isEmpty else { return false }
        guard latitude != nil, longitude != nil else { return false }
        guard finalPrice != nil else { return false }
        let hasNewImage = attachments.contains { $0.uploadedPath != nil }
        let hasExistingImage = existingThumbnails.contains { !$0.isMarkedForDeletion }
        guard hasNewImage || hasExistingImage else { return false }
        return true
    }

    // 편집 모드 진입 시 detail을 다시 fetch해서 폼을 prefill한다.
    // 후속 커밋(수정 모드 단계)에서 실제 구현 — 스켈레톤에서는 no-op.
    func loadInitialDataIfNeeded() async {
        guard case .edit = mode else { return }
        // TODO: ActivityRouter.detail 호출 후 폼 필드/existingThumbnails prefill
    }

    // 이미지 업로드 → DTO 빌드 → create/update 호출.
    // 후속 커밋(제출 로직 단계)에서 실제 구현 — 스켈레톤에서는 placeholder만.
    func submit() async -> Bool {
        formMessage = "제출 로직은 다음 커밋에서 연결됩니다."
        return false
    }
}
