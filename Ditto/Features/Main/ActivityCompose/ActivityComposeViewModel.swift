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
    func loadInitialDataIfNeeded() async {
        guard case .edit(let activityId) = mode else { return }
        guard !isPrefilling else { return }

        isPrefilling = true
        defer { isPrefilling = false }

        do {
            let networkManager = try networkManagerProvider()
            let dto: ActivityResponseDTO = try await networkManager.request(
                ActivityRouter.detail(activityId: activityId)
            )
            applyPrefill(from: dto)
        } catch {
            formMessage = Self.makeErrorMessage(from: error, fallback: "액티비티 정보를 불러오지 못했습니다.")
        }
    }

    func toggleExistingThumbnailDeletion(_ id: UUID) {
        guard let index = existingThumbnails.firstIndex(where: { $0.id == id }) else { return }
        existingThumbnails[index].isMarkedForDeletion.toggle()
    }

    private func applyPrefill(from dto: ActivityResponseDTO) {
        title = dto.title ?? ""
        country = dto.country ?? ""
        category = dto.category ?? ""
        descriptionText = dto.description ?? ""

        latitude = dto.geolocation.latitude
        longitude = dto.geolocation.longitude

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        startDate = dto.startDate.flatMap { isoFormatter.date(from: $0) }
        endDate = dto.endDate.flatMap { isoFormatter.date(from: $0) }

        schedule = (dto.schedule ?? []).map { item in
            ActivityComposeScheduleDraft(
                id: UUID(),
                duration: item.duration ?? "",
                description: item.description ?? ""
            )
        }

        originalPrice = dto.price.original
        finalPrice = dto.price.final
        pointReward = dto.pointReward
        minHeight = dto.restrictions.minHeight
        minAge = dto.restrictions.minAge
        maxParticipants = dto.restrictions.maxParticipants

        isAdvertisement = dto.isAdvertisement
        tagsText = dto.tags.joined(separator: ", ")

        existingThumbnails = dto.thumbnails.map { path in
            ActivityComposeExistingThumbnail(id: UUID(), path: path, isMarkedForDeletion: false)
        }
    }

    // 진행 중인 업로드가 있으면 짧게 폴링하며 대기한 뒤, 실패가 없으면 DTO를 빌드해 create/update를 호출한다.
    func submit() async -> Bool {
        guard canSubmit else { return false }

        isSubmitting = true
        formMessage = nil
        defer { isSubmitting = false }

        // 업로드가 끝날 때까지 잠깐 대기. canSubmit는 .uploaded 1장 보장만 하므로
        // 추가로 진행 중인 첨부가 있으면 그 결과까지 반영해야 thumbnails가 올바르다.
        while attachments.contains(where: { Self.isUploading($0) }) {
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        if attachments.contains(where: { Self.isFailed($0) }) {
            formMessage = "업로드에 실패한 사진이 있습니다. 해당 사진을 삭제한 뒤 다시 시도해 주세요."
            return false
        }

        let request = buildRequestDTO()

        do {
            let networkManager = try networkManagerProvider()
            switch mode {
            case .create:
                let _: ActivityResponseDTO = try await networkManager.request(ActivityRouter.create(request))
            case .edit(let activityId):
                let _: ActivityResponseDTO = try await networkManager.request(
                    ActivityRouter.update(activityId: activityId, request: request)
                )
            }
            didSubmitSuccessfully = true
            return true
        } catch {
            formMessage = Self.makeErrorMessage(from: error, fallback: "저장에 실패했습니다.")
            return false
        }
    }
}

// MARK: - 제출 DTO 빌드
private extension ActivityComposeViewModel {
    func buildRequestDTO() -> ActivityCreateRequestDTO {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)

        let activeExistingThumbnails = existingThumbnails
            .filter { !$0.isMarkedForDeletion }
            .map { $0.path }
        let newThumbnails = attachments.compactMap { $0.uploadedPath }
        let thumbnails = activeExistingThumbnails + newThumbnails

        let tags = parsedTags()
        let scheduleItems = parsedSchedule()

        return ActivityCreateRequestDTO(
            title: trimmedTitle.isEmpty ? nil : trimmedTitle,
            country: country.isEmpty ? nil : country,
            category: category.isEmpty ? nil : category,
            latitude: latitude,
            longitude: longitude,
            startDate: startDate.flatMap { isoFormatter.string(from: $0) },
            endDate: endDate.flatMap { isoFormatter.string(from: $0) },
            originalPrice: originalPrice,
            finalPrice: finalPrice,
            tags: tags,
            pointReward: pointReward,
            minHeight: minHeight,
            minAge: minAge,
            maxParticipants: maxParticipants,
            description: trimmedDescription.isEmpty ? nil : trimmedDescription,
            isAdvertisement: isAdvertisement,
            schedule: scheduleItems,
            thumbnails: thumbnails.isEmpty ? nil : thumbnails
        )
    }

    func parsedTags() -> [String]? {
        let items = tagsText
            .split { $0 == "," || $0 == "\n" }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return items.isEmpty ? nil : items
    }

    func parsedSchedule() -> [ActivityScheduleItemRequestDTO]? {
        let items = schedule.compactMap { draft -> ActivityScheduleItemRequestDTO? in
            let duration = draft.duration.trimmingCharacters(in: .whitespacesAndNewlines)
            let description = draft.description.trimmingCharacters(in: .whitespacesAndNewlines)
            if duration.isEmpty && description.isEmpty {
                return nil
            }
            return ActivityScheduleItemRequestDTO(
                duration: duration.isEmpty ? nil : duration,
                description: description.isEmpty ? nil : description
            )
        }
        return items.isEmpty ? nil : items
    }

    static func isUploading(_ attachment: ActivityComposeAttachment) -> Bool {
        if case .uploading = attachment.state { return true }
        return false
    }

    static func isFailed(_ attachment: ActivityComposeAttachment) -> Bool {
        if case .failed = attachment.state { return true }
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
