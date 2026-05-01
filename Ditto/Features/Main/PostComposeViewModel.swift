//
//  PostComposeViewModel.swift
//  Ditto
//
//  Created by Codex on 4/29/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class PostComposeViewModel {
    var title: String = ""
    var content: String = ""
    var country: String
    var category: String

    private(set) var attachments: [PostComposeAttachment] = []
    private(set) var selectedActivity: PostComposeActivityCandidate?
    private(set) var activitySearchKeyword: String = ""
    private(set) var activityCandidates: [PostComposeActivityCandidate] = []
    private(set) var isSearchingActivities = false
    private(set) var isSubmitting = false
    private(set) var formMessage: String?
    private(set) var didSubmitSuccessfully = false
    private(set) var activityCategoryFilter: String?

    let countryOptions: [String]

    private let networkManagerProvider: @MainActor () throws -> any NetworkManaging
    private let configurationProvider: @MainActor () throws -> AppConfiguration
    private let authManager: (any AuthManaging)?

    convenience init(
        initialContext: PostComposeInitialContext,
        authManager: any AuthManaging
    ) {
        self.init(
            initialContext: initialContext,
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
        initialContext: PostComposeInitialContext,
        networkManagerProvider: @escaping @MainActor () throws -> any NetworkManaging,
        configurationProvider: @escaping @MainActor () throws -> AppConfiguration,
        authManager: (any AuthManaging)?
    ) {
        self.country = initialContext.country
        self.category = initialContext.category
        self.networkManagerProvider = networkManagerProvider
        self.configurationProvider = configurationProvider
        self.authManager = authManager
        self.countryOptions = MainCountryFilter.samples.map { $0.name }
    }

    var canSubmit: Bool {
        guard !isSubmitting else { return false }
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard !country.isEmpty, !category.isEmpty else { return false }
        guard selectedActivity != nil else { return false }
        guard attachments.allSatisfy({ $0.uploadedPath != nil || isAttachmentUploading($0) == false }) else {
            return false
        }
        return true
    }

    func updateActivitySearchKeyword(_ keyword: String) {
        activitySearchKeyword = keyword
    }

    func selectActivity(_ activity: PostComposeActivityCandidate?) {
        selectedActivity = activity
        // 액티비티가 카테고리를 들고 있다면 폼의 카테고리는 그것을 그대로 따라간다.
        if let activityCategory = activity?.category, !activityCategory.isEmpty {
            category = activityCategory
        }
    }

    func searchActivities() async {
        let trimmed = activitySearchKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            await loadActivitiesByCategory()
            return
        }

        // 검색어 모드로 전환되었으니 카테고리 칩은 "전체"로 리셋한다.
        activityCategoryFilter = nil
        isSearchingActivities = true
        defer { isSearchingActivities = false }

        do {
            let networkManager = try networkManagerProvider()
            let response: ActivitySummaryListResponseDTO = try await networkManager.request(
                ActivityRouter.search(title: trimmed)
            )
            activityCandidates = response.data.map(Self.makeCandidate)

            if activityCandidates.isEmpty {
                formMessage = "검색 결과가 없습니다."
            } else {
                formMessage = nil
            }
        } catch {
            formMessage = Self.makeErrorMessage(from: error, fallback: "액티비티 검색에 실패했습니다.")
        }
    }

    func selectActivityCategory(_ category: String?) async {
        // 카테고리 모드로 전환 시, 검색어는 비워서 모드 충돌을 피한다.
        activitySearchKeyword = ""
        activityCategoryFilter = category
        await loadActivitiesByCategory()
    }

    func loadActivitiesByCategory() async {
        isSearchingActivities = true
        defer { isSearchingActivities = false }

        do {
            let networkManager = try networkManagerProvider()
            let query = ActivityListQuery(
                country: country,
                category: activityCategoryFilter,
                limit: 20,
                next: nil
            )
            let response: ActivitySummaryListResponseDTO = try await networkManager.request(
                ActivityRouter.list(query)
            )
            activityCandidates = response.data.map(Self.makeCandidate)

            if activityCandidates.isEmpty {
                formMessage = "조건에 맞는 액티비티가 없습니다."
            } else {
                formMessage = nil
            }
        } catch {
            formMessage = Self.makeErrorMessage(from: error, fallback: "액티비티 목록을 불러오지 못했습니다.")
        }
    }

    func appendAttachments(_ datas: [Data]) {
        let newAttachments = datas.map { data in
            PostComposeAttachment(id: UUID(), previewData: data, state: .uploading)
        }
        attachments.append(contentsOf: newAttachments)

        for attachment in newAttachments {
            uploadAttachment(attachment)
        }
    }

    func removeAttachment(_ id: UUID) {
        attachments.removeAll { $0.id == id }
    }

    func submit() async -> Bool {
        guard canSubmit else { return false }

        isSubmitting = true
        formMessage = nil
        defer { isSubmitting = false }

        // 포스트 작성에서는 위치 첨부를 사용하지 않으므로 좌표는 0,0으로 전송한다.
        let request = PostRequestDTO(
            country: country,
            category: category,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            content: content.trimmingCharacters(in: .whitespacesAndNewlines),
            activityId: selectedActivity?.id,
            latitude: 0,
            longitude: 0,
            files: attachments.compactMap { $0.uploadedPath }
        )

        do {
            let networkManager = try networkManagerProvider()
            let _: PostResponseDTO = try await networkManager.request(PostRouter.create(request))
            didSubmitSuccessfully = true
            return true
        } catch {
            formMessage = Self.makeErrorMessage(from: error, fallback: "게시에 실패했습니다.")
            return false
        }
    }
}

private extension PostComposeViewModel {
    func uploadAttachment(_ attachment: PostComposeAttachment) {
        Task { [weak self] in
            guard let self else { return }

            do {
                let networkManager = try self.networkManagerProvider()
                let file = MultipartFile(
                    filename: "post_\(attachment.id.uuidString).jpg",
                    mimeType: "image/jpeg",
                    data: attachment.previewData
                )
                let response: FileResponseDTO = try await networkManager.request(
                    PostRouter.uploadFiles(PostFileUploadRequestDTO(files: [file]))
                )

                guard let path = response.files.first else {
                    self.markAttachmentFailed(attachment.id, message: "업로드 응답이 비어 있습니다.")
                    return
                }

                self.markAttachmentUploaded(attachment.id, path: path)
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

    func isAttachmentUploading(_ attachment: PostComposeAttachment) -> Bool {
        if case .uploading = attachment.state { return true }
        return false
    }

    static func makeCandidate(from response: ActivitySummaryResponseDTO) -> PostComposeActivityCandidate {
        PostComposeActivityCandidate(
            id: response.activityId,
            title: response.title ?? "제목 없는 액티비티",
            country: response.country,
            category: response.category
        )
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
