//
//  VideoFeedView.swift
//  Ditto
//
//  Created by Codex on 5/5/26.
//

import AVFoundation
import SwiftUI

// 쇼츠 스타일의 세로 풀스크린 영상 피드.
// 한 페이지 = 영상 1개. 화면에 보이는 페이지만 재생되도록 currentVideoID로 관리한다.
struct VideoFeedView: View {
    @State private var viewModel: VideoListViewModel
    @State private var currentVideoID: String?
    @State private var isPaused = false
    @State private var isSubtitleEnabled = false
    @State private var currentSubtitleText: String?
    @State private var availableSubtitles: [StreamSubtitleDTO] = []
    // 사용자가 직접 고른 자막 언어. nil이면 isDefault 자막을 자동 사용한다.
    @State private var selectedSubtitleLanguage: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    init(authManager: any AuthManaging) {
        _viewModel = State(initialValue: VideoListViewModel(authManager: authManager))
    }

    private var currentVideo: VideoResponseDTO? {
        guard let id = currentVideoID else { return viewModel.videos.first }
        return viewModel.videos.first { $0.videoId == id } ?? viewModel.videos.first
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            content

            // 영상 정보 오버레이 — 카드 외부 z-order에 그려야 AVPlayer view 위에 안정적으로 보인다.
            if let video = currentVideo {
                infoOverlay(for: video)
            }

            // 자막도 카드 외부 z-order에 그려 AVPlayer view에 가려지지 않도록 한다.
            subtitleOverlay

            VStack {
                topBar
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
        .preferredColorScheme(.dark)
        .task {
            if viewModel.videos.isEmpty {
                await viewModel.loadFirstPage()
                if currentVideoID == nil, let firstID = viewModel.videos.first?.videoId {
                    currentVideoID = firstID
                }
            }
        }
        .onChange(of: currentVideoID) { _, _ in
            // 다른 영상으로 넘어가면 일시정지 상태 초기화
            isPaused = false
        }
        .onChange(of: scenePhase) { _, newPhase in
            // 다른 앱·컨트롤 센터·알림으로 화면을 벗어나면 영상을 멈춰둔다.
            // 복귀 시 자동 재생하지 않고 사용자가 명시적으로 탭하도록 한다(의도치 않은 사운드 재개 방지).
            if newPhase != .active {
                isPaused = true
            }
        }
        // 무음 모드(silent switch)에서도 영상 사운드가 들리도록 .playback 카테고리로 활성화한다.
        // 화면을 닫으면 다른 앱에 다시 오디오 권한을 돌려준다.
        .onAppear { activateAudioSession() }
        .onDisappear { deactivateAudioSession() }
    }

    private func activateAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .moviePlayback)
            try session.setActive(true)
        } catch {
            // 설정 실패해도 재생 자체는 가능하므로 조용히 무시한다.
        }
    }

    private func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.videos.isEmpty {
            ProgressView()
                .tint(.white)
        } else if viewModel.videos.isEmpty {
            emptyState
        } else {
            feed
        }
    }

    private var feed: some View {
        // ScrollView를 풀스크린으로 깔고, 각 카드를 컨테이너(=ScrollView) 크기와 동일하게 잡아
        // 한 페이지 = 한 영상이 정확히 일치하도록 한다.
        ScrollView(.vertical, showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.videos, id: \.videoId) { video in
                    VideoFeedPlayerCard(
                        video: video,
                        isActive: currentVideoID == video.videoId,
                        isPaused: currentVideoID == video.videoId && isPaused,
                        isSubtitleEnabled: isSubtitleEnabled,
                        selectedSubtitleLanguage: selectedSubtitleLanguage,
                        onTapPlayer: {
                            if currentVideoID == video.videoId {
                                isPaused.toggle()
                            }
                        },
                        viewModel: viewModel,
                        onSubtitleChange: { newText in
                            // 활성 카드만 자막을 보내므로 그대로 받아 그린다.
                            // 카드 전환 직후 비활성 카드의 nil 콜백이 늦게 들어와도, 다음 활성 콜백이 덮어쓴다.
                            currentSubtitleText = newText
                        },
                        onSubtitlesAvailable: { subtitles in
                            // 활성 카드의 자막 목록을 받아 메뉴에 표시한다.
                            availableSubtitles = subtitles
                        }
                    )
                    .containerRelativeFrame([.horizontal, .vertical])
                    .id(video.videoId)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $currentVideoID)
        .ignoresSafeArea()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "film")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.white.opacity(0.7))

            Text(viewModel.message ?? "표시할 영상이 없어요.")
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
    }

    @ViewBuilder
    private func infoOverlay(for video: VideoResponseDTO) -> some View {
        // ScrollView paging 제스처를 가리지 않도록 hit-test가 필요한 영역(좋아요 버튼 등)만 갖는다.
        // 일시정지 시 ▶︎ 아이콘은 화면 중앙에 표시하되 hit-test는 받지 않도록 한다.
        ZStack {
            if isPaused {
                Image(systemName: "play.fill")
                    .font(.system(size: 56, weight: .bold))
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(radius: 6)
                    .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                Spacer()
                bottomInfo(for: video)
            }
        }
    }

    private func bottomInfo(for video: VideoResponseDTO) -> some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(video.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(video.description)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(3)

                HStack(spacing: 10) {
                    Label(formattedDuration(video.duration), systemImage: "clock")
                    Label("\(video.viewCount)", systemImage: "eye")
                }
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 18) {
                let busy = viewModel.togglingLikeIDs.contains(video.videoId)
                Button {
                    Task { await viewModel.toggleLike(for: video.videoId) }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: video.isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(video.isLiked ? .pink : .white)
                            .opacity(busy ? 0.5 : 1.0)
                        Text("\(video.likeCount)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .disabled(busy)
            }
            .layoutPriority(1)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0), Color.black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        )
    }

    private func formattedDuration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Circle().fill(.black.opacity(0.35)))
            }
            .buttonStyle(.plain)

            Spacer()

            Text("영상")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)

            Spacer()

            // 자막 메뉴(끄기 + 언어 선택). 좌측 X 버튼과 시각적 균형도 맞춘다(44×44).
            subtitleMenu
        }
    }

    private var subtitleMenu: some View {
        Menu {
            Button {
                isSubtitleEnabled = false
            } label: {
                if isSubtitleEnabled {
                    Text("끄기")
                } else {
                    Label("끄기", systemImage: "checkmark")
                }
            }
            if !availableSubtitles.isEmpty {
                Divider()
                ForEach(availableSubtitles, id: \.language) { subtitle in
                    Button {
                        selectedSubtitleLanguage = subtitle.language
                        isSubtitleEnabled = true
                    } label: {
                        if isCurrentlySelected(subtitle) {
                            Label(subtitle.name, systemImage: "checkmark")
                        } else {
                            Text(subtitle.name)
                        }
                    }
                }
            }
        } label: {
            Image(systemName: isSubtitleEnabled ? "captions.bubble.fill" : "captions.bubble")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.black.opacity(0.35)))
        }
        .accessibilityLabel("자막 설정")
    }

    private func isCurrentlySelected(_ subtitle: StreamSubtitleDTO) -> Bool {
        // 자막이 켜져 있을 때만 체크 표시. 사용자 선택값이 있으면 그것 우선, 없으면 isDefault.
        guard isSubtitleEnabled else { return false }
        if let selected = selectedSubtitleLanguage {
            return selected == subtitle.language
        }
        return subtitle.isDefault
    }

    @ViewBuilder
    private var subtitleOverlay: some View {
        if isSubtitleEnabled,
           let text = currentSubtitleText,
           !text.isEmpty {
            VStack {
                Spacer()
                Text(text)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(.black.opacity(0.6))
                    )
                    .padding(.horizontal, 24)
                    // bottomInfo(제목/설명/좋아요)와 겹치지 않도록 충분히 위로 띄운다.
                    .padding(.bottom, 200)
            }
            .allowsHitTesting(false)
            .transition(.opacity)
        }
    }
}
