//
//  LikesZoomOverlay.swift
//  Ditto
//
//  Created by Codex on 5/1/26.
//

import SwiftUI
import UIKit

// 좋아요 카드 이미지 위치를 zoom 오버레이가 읽을 수 있도록 anchor를 발행한다.
// key는 activityId, value는 카드 이미지의 bounds anchor.
struct LikesZoomCardAnchorKey: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue()) { _, new in new }
    }
}

// 카드 → 상세 hero로 이미지가 확대되는 zoom 트랜지션 오버레이.
// MainView 최상단에서 NavigationStack 위에 그려져, push 슬라이드보다 위에 보인다.
struct LikesZoomOverlay: View {
    let imageRequest: URLRequest?
    let source: CGRect
    let destination: CGRect
    let onComplete: () -> Void

    @State private var trigger = false

    var body: some View {
        LikesZoomImage(request: imageRequest)
            .keyframeAnimator(
                initialValue: ZoomFrame(
                    posX: source.midX,
                    posY: source.midY,
                    width: source.width,
                    height: source.height,
                    cornerRadius: 14
                ),
                trigger: trigger,
                content: { content, value in
                    content
                        .frame(width: max(value.width, 1), height: max(value.height, 1))
                        .clipShape(RoundedRectangle(cornerRadius: value.cornerRadius, style: .continuous))
                        .position(x: value.posX, y: value.posY)
                },
                keyframes: { _ in
                    KeyframeTrack(\.posX) {
                        SpringKeyframe(destination.midX, duration: 0.42, spring: .smooth)
                    }
                    KeyframeTrack(\.posY) {
                        SpringKeyframe(destination.midY, duration: 0.42, spring: .smooth)
                    }
                    KeyframeTrack(\.width) {
                        SpringKeyframe(destination.width, duration: 0.42, spring: .smooth)
                    }
                    KeyframeTrack(\.height) {
                        SpringKeyframe(destination.height, duration: 0.42, spring: .smooth)
                    }
                    KeyframeTrack(\.cornerRadius) {
                        LinearKeyframe(0, duration: 0.42)
                    }
                }
            )
            .allowsHitTesting(false)
            .onAppear {
                trigger.toggle()
                Task {
                    try? await Task.sleep(for: .milliseconds(440))
                    onComplete()
                }
            }
    }
}

private struct ZoomFrame {
    var posX: CGFloat
    var posY: CGFloat
    var width: CGFloat
    var height: CGFloat
    var cornerRadius: CGFloat
}

// zoom 오버레이용 경량 이미지 뷰. 캐시 없이 단발성 로딩이라 화면 빠르게 잡히면 그만이다.
private struct LikesZoomImage: View {
    let request: URLRequest?
    @State private var remoteImage: UIImage?

    var body: some View {
        Group {
            if let remoteImage {
                Image(uiImage: remoteImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.gray.opacity(0.18)
            }
        }
        .clipped()
        .task {
            guard let request, remoteImage == nil else { return }
            if let (data, _) = try? await URLSession.shared.data(for: request),
               let img = UIImage(data: data) {
                remoteImage = img
            }
        }
    }
}
