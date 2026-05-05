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

// MARK: - 일정(schedule) 관리
extension ActivityComposeViewModel {
    func addScheduleItem() {
        schedule.append(ActivityComposeScheduleDraft(id: UUID()))
    }

    func removeScheduleItem(_ id: UUID) {
        schedule.removeAll { $0.id == id }
    }
}

// MARK: - 미디어(첨부 사진) 관리
extension ActivityComposeViewModel {
    // 사진 슬롯은 신규 업로드와 기존(편집) 썸네일을 합쳐 최대 5장으로 제한한다.
    static let maxThumbnailCount = 5

    var availableSlotCount: Int {
        let activeExisting = existingThumbnails.filter { !$0.isMarkedForDeletion }.count
        return max(0, Self.maxThumbnailCount - activeExisting - attachments.count)
    }

    // 라이브러리에서 선택한 Data 묶음을 받아 attachment를 추가하고 백그라운드 업로드를 시작한다.
    func appendAttachments(_ datas: [Data]) {
        let newAttachments = datas.map { data in
            ActivityComposeAttachment(id: UUID(), previewData: data, state: .uploading)
        }
        attachments.append(contentsOf: newAttachments)
        for attachment in newAttachments {
            uploadAttachment(attachment)
        }
    }

    func removeAttachment(_ id: UUID) {
        attachments.removeAll { $0.id == id }
    }
}

private extension ActivityComposeViewModel {
    func uploadAttachment(_ attachment: ActivityComposeAttachment) {
        Task { [weak self] in
            guard let self else { return }

            do {
                let networkManager = try self.networkManagerProvider()
                let file = try MultipartFile(
                    filename: "activity_\(attachment.id.uuidString).jpg",
                    mimeType: "image/jpeg",
                    data: attachment.previewData
                )
                .validated(against: .activityFiles)
                let response: ActivityFileResponseDTO = try await networkManager.request(
                    ActivityRouter.uploadFiles(ActivityFileUploadRequestDTO(files: [file]))
                )

                guard let path = response.thumbnails?.first else {
                    self.markAttachmentFailed(attachment.id, message: "업로드 응답이 비어 있습니다.")
                    return
                }

                self.markAttachmentUploaded(attachment.id, path: path)
            } catch let validationError as MultipartUploadError {
                self.markAttachmentFailed(attachment.id, message: validationError.userMessage)
            } catch {
                let message = Self.makeErrorMessage(from: error, fallback: "사진 업로드에 실패했습니다.")
                self.markAttachmentFailed(attachment.id, message: message)
            }
        }
    }

    func markAttachmentUploaded(_ id: UUID, path: String) {
        guard let index = attachments.firstIndex(where: { $0.id == id }) else { return }
        attachments[index].state = .uploaded(path: path)
    }

    func markAttachmentFailed(_ id: UUID, message: String) {
        guard let index = attachments.firstIndex(where: { $0.id == id }) else { return }
        attachments[index].state = .failed(message: message)
        formMessage = message
    }

    static func makeErrorMessage(from error: Error, fallback: String) -> String {
        switch error {
        case let error as NetworkError:
            switch error {
            case .missingAuthenticationToken:
                return "로그인이 필요합니다."
            case .statusCode(_, let message, _):
                return message ?? fallback
            case .requestFailed:
                return "네트워크 연결을 확인해 주세요."
            case .decodingFailed:
                return fallback
            case .invalidURL:
                return "요청 주소가 올바르지 않습니다."
            case .invalidResponse:
                return "서버 응답을 확인할 수 없습니다."
            case .encodingFailed:
                return "요청 데이터를 만들 수 없습니다."
            }
        case AppConfigurationError.missingValue, AppConfigurationError.invalidURL:
            return "API 설정값을 확인해 주세요."
        default:
            return fallback
        }
    }
}
