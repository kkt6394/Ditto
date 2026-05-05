//
//  VideoFeedPlayerCard.swift
//  Ditto
//
//  Created by Codex on 5/5/26.
//

import AVFoundation
import AVKit
import SwiftUI

// 쇼츠 카드 1장. AVPlayer 영상과 썸네일만 그린다.
// 좋아요/제목/설명/일시정지 아이콘 등 SwiftUI 오버레이는 부모(VideoFeedView)에서 카드 외부 z-order에
// 그린다. 카드 안에 SwiftUI 자식을 두면 AVPlayer view가 합성 시 위로 올라와 가린다.
struct VideoFeedPlayerCard: View {
    let video: VideoResponseDTO
    let isActive: Bool
    let isPaused: Bool
    // 영상 영역 탭 시 부모에 알린다. 화면 전체에 탭 영역을 깔면 ScrollView paging이 막혀서
    // 카드 안 player view에만 한정해서 hit-test를 받도록 한다.
    let onTapPlayer: () -> Void
    let viewModel: VideoListViewModel

    @State private var player: AVPlayer?
    @State private var streamLoadFailed = false
    @State private var isLoadingStream = false
    @State private var thumbnailImage: UIImage?

    var body: some View {
        ZStack {
            thumbnailLayer

            if let player {
                VideoPlayerLayerView(player: player)
                    .onTapGesture {
                        onTapPlayer()
                    }
            }
        }
        .background(Color.black)
        .clipped()
        .task {
            await prepareIfNeeded()
            if isActive, !isPaused {
                await player?.seek(to: .zero)
                player?.play()
            }
        }
        .task {
            await loadThumbnail()
        }
        .onChange(of: isActive) { _, newValue in
            if newValue {
                Task {
                    await prepareIfNeeded()
                    await player?.seek(to: .zero)
                    if !isPaused { player?.play() }
                }
            } else {
                player?.pause()
            }
        }
        .onChange(of: isPaused) { _, paused in
            guard isActive else { return }
            if paused {
                player?.pause()
            } else {
                player?.play()
            }
        }
        .onDisappear {
            player?.pause()
        }
    }

    @ViewBuilder
    private var thumbnailLayer: some View {
        if let image = thumbnailImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.15))
        } else {
            Color.black
        }
    }

    private func prepareIfNeeded(force: Bool = false) async {
        if !force, player != nil { return }
        guard !isLoadingStream else { return }

        isLoadingStream = true
        streamLoadFailed = false
        defer { isLoadingStream = false }

        do {
            let response = try await viewModel.fetchStreamURL(videoId: video.videoId)
            guard let url = viewModel.makeStreamURL(from: response.streamUrl) else {
                streamLoadFailed = true
                return
            }
            // master.m3u8 뿐 아니라 안에서 자동 요청되는 화질 플레이리스트, init.mp4, .m4s 세그먼트,
            // 자막 vtt에도 SeSACKey 헤더가 그대로 따라가도록 AVURLAsset 옵션으로 주입한다.
            let asset = AVURLAsset(
                url: url,
                options: ["AVURLAssetHTTPHeaderFieldsKey": viewModel.streamHTTPHeaders()]
            )
            let item = AVPlayerItem(asset: asset)
            let newPlayer = AVPlayer(playerItem: item)
            newPlayer.actionAtItemEnd = .none
            // 영상 끝나면 처음부터 자동 반복 (쇼츠 패턴)
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: item,
                queue: .main
            ) { _ in
                newPlayer.seek(to: .zero)
                newPlayer.play()
            }
            player = newPlayer
        } catch {
            streamLoadFailed = true
        }
    }

    private func loadThumbnail() async {
        guard thumbnailImage == nil else { return }
        guard let request = viewModel.makeAuthorizedImageRequest(for: video.thumbnailUrl) else { return }
        let size = UIScreen.main.bounds.size
        if let image = try? await RemoteImageLoader.load(request: request, pointSize: size) {
            thumbnailImage = image
        }
    }
}

// AVPlayerViewController 기반 SwiftUI 뷰. UIViewRepresentable + AVPlayerLayer 조합은
// SwiftUI 합성 트리에서 SwiftUI overlay가 가려지는 z-order 이슈가 있어, 표준 컨트롤러
// 컨테이너로 감싸 SwiftUI overlay가 안정적으로 위에 그려지도록 한다.
private struct VideoPlayerLayerView: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context _: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        // 쇼츠 UX: 기본 재생 컨트롤은 숨기고 우리 SwiftUI 오버레이로만 조작한다.
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        controller.allowsPictureInPicturePlayback = false
        controller.view.backgroundColor = .black
        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context _: Context) {
        if uiViewController.player !== player {
            uiViewController.player = player
        }
    }
}
