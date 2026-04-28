//
//  ActivityPostMediaViewer.swift
//  Ditto
//
//  Created by Codex on 4/28/26.
//

import AVKit
import SwiftUI
import UIKit

struct ActivityPostMediaViewer: View {
    @Environment(\.dismiss) private var dismiss

    let media: MainPostMedia
    private let authManager: any AuthManaging

    @State private var player: AVPlayer?
    @State private var image: UIImage?
    @State private var message: String?
    @State private var scale: CGFloat = 1

    init(media: MainPostMedia, authManager: any AuthManaging) {
        self.media = media
        self.authManager = authManager
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            content

            Button {
                player?.pause()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.black.opacity(0.45), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 14)
            .padding(.trailing, 14)
        }
        .task(id: media.id) {
            await loadMedia()
        }
        .onDisappear {
            player?.pause()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch media.kind {
        case .image:
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = max(1, min(value, 4))
                            }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                mediaStateView
            }
        case .video:
            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                mediaStateView
            }
        }
    }

    private var mediaStateView: some View {
        VStack(spacing: 12) {
            if message == nil {
                ProgressView()
                    .tint(.white)
            }

            Text(message ?? "미디어를 불러오는 중입니다.")
                .font(MainScreenTypography.body)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadMedia() async {
        message = nil

        switch media.kind {
        case .image:
            await loadImage()
        case .video:
            await loadVideo()
        }
    }

    private func loadImage() async {
        guard let request = media.request else {
            message = "사진을 불러올 수 없습니다."
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let loadedImage = UIImage(data: data) else {
                message = "사진을 불러올 수 없습니다."
                return
            }

            image = loadedImage
        } catch {
            message = "네트워크 연결을 확인해 주세요."
        }
    }

    private func loadVideo() async {
        do {
            let request = try await makeVideoRequest()
            guard let request else {
                message = "영상을 재생할 수 없습니다."
                return
            }

            guard let url = request.url else {
                message = "영상을 재생할 수 없습니다."
                return
            }

            let asset = AVURLAsset(
                url: url,
                options: ["AVURLAssetHTTPHeaderFieldsKey": request.allHTTPHeaderFields ?? [:]]
            )
            let playerItem = AVPlayerItem(asset: asset)
            let videoPlayer = AVPlayer(playerItem: playerItem)
            player = videoPlayer
            videoPlayer.play()
        } catch {
            message = makeVideoErrorMessage(from: error)
        }
    }

    private func makeVideoRequest() async throws -> URLRequest? {
        if let videoId = media.videoId {
            let configuration = try AppConfiguration()
            let networkManager = NetworkManager(configuration: configuration, authManager: authManager)
            let response: StreamUrlResponseDTO = try await networkManager.request(VideoRouter.stream(videoId: videoId))
            return makeAuthenticatedRequest(
                from: response.streamUrl,
                configuration: configuration,
                accessToken: authManager.tokens?.accessToken
            )
        }

        return media.request
    }

    private func makeAuthenticatedRequest(
        from path: String,
        configuration: AppConfiguration,
        accessToken: String?
    ) -> URLRequest? {
        guard let url = makeURL(from: path, baseURL: configuration.baseURL) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue(configuration.apiKey, forHTTPHeaderField: "SeSACKey")

        if let accessToken {
            request.setValue(accessToken, forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func makeURL(from path: String, baseURL: URL) -> URL? {
        if let url = URL(string: path), url.scheme != nil {
            return url
        }

        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var mediaPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if mediaPath.hasPrefix("data/") {
            mediaPath = "v1/" + mediaPath
        }

        components.path = "/" + [basePath, mediaPath]
            .filter { !$0.isEmpty }
            .joined(separator: "/")

        return components.url
    }

    private func makeVideoErrorMessage(from error: Error) -> String {
        switch error {
        case let error as NetworkError:
            switch error {
            case .missingAuthenticationToken:
                return "로그인이 필요합니다."
            case .statusCode(_, let message, _):
                return message ?? "스트리밍 정보를 불러오지 못했습니다."
            case .requestFailed:
                return "네트워크 연결을 확인해 주세요."
            default:
                return "영상을 재생할 수 없습니다."
            }
        case AppConfigurationError.missingValue, AppConfigurationError.invalidURL:
            return "API 설정값을 확인해 주세요."
        default:
            return "영상을 재생할 수 없습니다."
        }
    }
}
