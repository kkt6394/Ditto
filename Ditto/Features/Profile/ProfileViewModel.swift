//
//  ProfileViewModel.swift
//  Ditto
//
//  Created by Codex on 5/1/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class ProfileViewModel {
    // 프로필 본문 상태
    private(set) var profile: ProfileSummary?
    private(set) var profileImageRequest: URLRequest?
    private(set) var isLoadingProfile = false
    private(set) var profileMessage: String?

    // 내가 작성한 포스트
    private(set) var myPosts: [ProfilePostPreview] = []
    private(set) var isLoadingMyPosts = false
    private(set) var myPostsMessage: String?

    // 내가 좋아요한 포스트
    private(set) var likedPosts: [ProfilePostPreview] = []
    private(set) var isLoadingLikedPosts = false
    private(set) var likedPostsMessage: String?

    // 액션 진행 상태(편집/이미지 업로드/회원탈퇴)
    private(set) var isUpdatingProfile = false
    private(set) var isUploadingImage = false
    private(set) var isWithdrawing = false
    var actionMessage: String?

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

    func loadAll() async {
        // 프로필이 먼저 와야 내 포스트 쿼리에 userId를 넘길 수 있어 직렬로 흐른다.
        await loadProfile()
        async let myPostsTask: Void = loadMyPosts()
        async let likedPostsTask: Void = loadLikedPosts()
        _ = await (myPostsTask, likedPostsTask)
    }

    func loadProfile() async {
        isLoadingProfile = true
        profileMessage = nil
        defer {
            isLoadingProfile = false
        }

        do {
            let networkManager = try networkManagerProvider()
            let configuration = try configurationProvider()
            let response: MyInfoResponseDTO = try await networkManager.request(UserRouter.myProfile)
            let summary = ProfileSummary(dto: response)
            profile = summary
            profileImageRequest = ActivityFormatting.makeImageRequest(
                from: summary.profileImagePath,
                configuration: configuration,
                accessToken: authManager.tokens?.accessToken
            )
        } catch {
            profileMessage = MainViewModel.makeNetworkErrorMessage(
                from: NetworkErrorAdapter.wrap(error),
                fallbackMessage: "프로필을 불러오지 못했습니다."
            )
        }
    }

    func loadMyPosts() async {
        guard let userId = profile?.userId else {
            // 프로필 로드 실패 시 내 포스트 호출 자체가 의미 없으므로 스킵한다.
            return
        }

        isLoadingMyPosts = true
        myPostsMessage = nil
        defer {
            isLoadingMyPosts = false
        }

        do {
            let networkManager = try networkManagerProvider()
            let configuration = try configurationProvider()
            let query = PostUserListQuery(
                country: nil,
                category: nil,
                userId: userId,
                limit: 10,
                next: nil
            )
            let response: PostSummaryPaginationResponseDTO = try await networkManager.request(
                PostRouter.userPosts(query)
            )

            let mapped = response.data.map { dto in
                Self.makeProfilePostPreview(
                    from: dto,
                    configuration: configuration,
                    accessToken: authManager.tokens?.accessToken
                )
            }

            myPosts = mapped

            if mapped.isEmpty {
                myPostsMessage = "아직 작성한 포스트가 없습니다."
            }
        } catch {
            myPostsMessage = MainViewModel.makeNetworkErrorMessage(
                from: NetworkErrorAdapter.wrap(error),
                fallbackMessage: "내 포스트를 불러오지 못했습니다."
            )
        }
    }

    func loadLikedPosts() async {
        isLoadingLikedPosts = true
        likedPostsMessage = nil
        defer {
            isLoadingLikedPosts = false
        }

        do {
            let networkManager = try networkManagerProvider()
            let configuration = try configurationProvider()
            let query = PostLikedListQuery(country: nil, category: nil, next: nil, limit: 10)
            let response: PostSummaryPaginationResponseDTO = try await networkManager.request(
                PostRouter.likedPosts(query)
            )
            let mapped = response.data.map { dto in
                Self.makeProfilePostPreview(
                    from: dto,
                    configuration: configuration,
                    accessToken: authManager.tokens?.accessToken
                )
            }

            likedPosts = mapped

            if mapped.isEmpty {
                likedPostsMessage = "아직 좋아요한 포스트가 없습니다."
            }
        } catch {
            likedPostsMessage = MainViewModel.makeNetworkErrorMessage(
                from: NetworkErrorAdapter.wrap(error),
                fallbackMessage: "좋아요한 포스트를 불러오지 못했습니다."
            )
        }
    }

    @discardableResult
    func updateProfile(
        nick: String,
        introduction: String?,
        phoneNumber: String?
    ) async -> Bool {
        isUpdatingProfile = true
        actionMessage = nil
        defer {
            isUpdatingProfile = false
        }

        let trimmedNick = nick.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedNick.isEmpty else {
            actionMessage = "닉네임을 입력해 주세요."
            return false
        }

        do {
            let networkManager = try networkManagerProvider()
            let request = ProfileRequestDTO(
                nick: trimmedNick,
                profileImage: profile?.profileImagePath,
                phoneNum: Self.normalizeOptional(phoneNumber),
                introduction: Self.normalizeOptional(introduction)
            )
            let response: MyInfoResponseDTO = try await networkManager.request(
                UserRouter.updateProfile(request)
            )
            let configuration = try configurationProvider()
            let summary = ProfileSummary(dto: response)
            profile = summary
            profileImageRequest = ActivityFormatting.makeImageRequest(
                from: summary.profileImagePath,
                configuration: configuration,
                accessToken: authManager.tokens?.accessToken
            )
            return true
        } catch {
            actionMessage = MainViewModel.makeNetworkErrorMessage(
                from: NetworkErrorAdapter.wrap(error),
                fallbackMessage: "프로필 수정에 실패했습니다."
            )
            return false
        }
    }

    @discardableResult
    func uploadProfileImage(data: Data) async -> Bool {
        guard !data.isEmpty else {
            actionMessage = "이미지를 다시 선택해 주세요."
            return false
        }

        isUploadingImage = true
        actionMessage = nil
        defer {
            isUploadingImage = false
        }

        do {
            let networkManager = try networkManagerProvider()
            let configuration = try configurationProvider()
            let file = MultipartFile(
                filename: "profile-\(UUID().uuidString).jpg",
                mimeType: "image/jpeg",
                data: data
            )
            let request = ProfileImageUploadRequestDTO(profile: file)
            let response: ProfileImageUploadResponseDTO = try await networkManager.request(
                UserRouter.uploadProfileImage(request)
            )

            // 업로드된 path를 그대로 PUT /me/profile에 보내야 새로 올린 이미지가 반영된다.
            let updateRequest = ProfileRequestDTO(
                nick: profile?.nick ?? "",
                profileImage: response.profileImage,
                phoneNum: profile?.phoneNumber,
                introduction: profile?.introduction
            )
            let updated: MyInfoResponseDTO = try await networkManager.request(
                UserRouter.updateProfile(updateRequest)
            )
            let summary = ProfileSummary(dto: updated)
            profile = summary
            profileImageRequest = ActivityFormatting.makeImageRequest(
                from: summary.profileImagePath,
                configuration: configuration,
                accessToken: authManager.tokens?.accessToken
            )
            return true
        } catch {
            actionMessage = MainViewModel.makeNetworkErrorMessage(
                from: NetworkErrorAdapter.wrap(error),
                fallbackMessage: "이미지 업로드에 실패했습니다."
            )
            return false
        }
    }

    @discardableResult
    func withdraw() async -> Bool {
        isWithdrawing = true
        actionMessage = nil
        defer {
            isWithdrawing = false
        }

        do {
            let networkManager = try networkManagerProvider()
            let _: WithdrawResponseDTO = try await networkManager.request(UserRouter.withdraw)
            // 서버 측 탈퇴가 끝나면 로컬 토큰도 즉시 정리해 로그인 화면으로 돌아가게 한다.
            try? authManager.signOut()
            return true
        } catch {
            actionMessage = MainViewModel.makeNetworkErrorMessage(
                from: NetworkErrorAdapter.wrap(error),
                fallbackMessage: "회원탈퇴에 실패했습니다."
            )
            return false
        }
    }
}

private extension ProfileViewModel {
    static func makeProfilePostPreview(
        from dto: PostSummaryResponseDTO,
        configuration: AppConfiguration,
        accessToken: String?
    ) -> ProfilePostPreview {
        let firstImagePath = dto.files.first { path in
            ActivityFormatting.isImagePath(path)
        }
        return ProfilePostPreview(
            id: dto.postId,
            title: dto.title,
            summary: dto.content,
            category: dto.activity?.title ?? dto.category,
            location: ActivityFormatting.makeLocationText(country: dto.country),
            imageRequest: ActivityFormatting.makeImageRequest(
                from: firstImagePath,
                configuration: configuration,
                accessToken: accessToken
            ),
            likeCount: Int(dto.likeCount.rounded())
        )
    }

    static func normalizeOptional(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

// NetworkError가 아닌 generic Error도 일관된 사용자 메시지로 변환할 수 있도록
// MainViewModel.makeNetworkErrorMessage가 받을 수 있는 형태로 감싼다.
private enum NetworkErrorAdapter {
    static func wrap(_ error: Error) -> NetworkError {
        if let networkError = error as? NetworkError {
            return networkError
        }
        return .requestFailed(error)
    }
}
