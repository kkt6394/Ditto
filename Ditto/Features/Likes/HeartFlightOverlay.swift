//
//  HeartFlightOverlay.swift
//  Ditto
//
//  Created by Codex on 5/1/26.
//

import SwiftUI

// 좋아요(keep) 추가 순간, 카드 위 하트가 좋아요 탭 아이콘으로 날아가는 듯한
// 비행 트랜지션을 위해 source/destination 좌표를 모아주는 PreferenceKey.
// key 는 activityId 이며, 좋아요 탭 아이콘은 sentinel 키(tabSentinelID)를 쓴다.
struct ActivityHeartAnchorKey: PreferenceKey {
    static let tabSentinelID: String = "__tab.likes__"

    static let defaultValue: [String: Anchor<CGPoint>] = [:]

    static func reduce(value: inout Value, nextValue: () -> Value) {
        value.merge(nextValue()) { _, new in new }
    }
}

// 좋아요 추가 시 잠깐 떠올라 좋아요 탭 아이콘으로 곡선 이동하는 하트.
struct FlyingHeart: View {
    let source: CGPoint
    let destination: CGPoint
    let onComplete: () -> Void

    @State private var trigger = false

    private static let likedColor = Color(red: 1.0, green: 0.38, blue: 0.52)

    private var arcPeakX: CGFloat {
        (source.x + destination.x) / 2
    }

    private var arcPeakY: CGFloat {
        min(source.y, destination.y) - 80
    }

    var body: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 30, weight: .bold))
            .foregroundStyle(Self.likedColor)
            .shadow(color: Self.likedColor.opacity(0.45), radius: 12, y: 4)
            .keyframeAnimator(
                initialValue: HeartFlightState(
                    posX: source.x,
                    posY: source.y,
                    scale: 1.0,
                    opacity: 1.0
                ),
                trigger: trigger,
                content: { content, state in
                    content
                        .scaleEffect(state.scale)
                        .opacity(state.opacity)
                        .position(x: state.posX, y: state.posY)
                },
                keyframes: { _ in
                    KeyframeTrack(\.posX) {
                        CubicKeyframe(arcPeakX, duration: 0.32)
                        CubicKeyframe(destination.x, duration: 0.4)
                    }
                    KeyframeTrack(\.posY) {
                        CubicKeyframe(arcPeakY, duration: 0.32)
                        CubicKeyframe(destination.y, duration: 0.4)
                    }
                    KeyframeTrack(\.scale) {
                        SpringKeyframe(1.45, duration: 0.18, spring: .bouncy)
                        CubicKeyframe(0.65, duration: 0.54)
                    }
                    KeyframeTrack(\.opacity) {
                        LinearKeyframe(1.0, duration: 0.55)
                        LinearKeyframe(0.0, duration: 0.17)
                    }
                }
            )
            .allowsHitTesting(false)
            .onAppear {
                trigger.toggle()
                Task {
                    try? await Task.sleep(for: .milliseconds(720))
                    onComplete()
                }
            }
    }
}

private struct HeartFlightState {
    var posX: CGFloat
    var posY: CGFloat
    var scale: CGFloat
    var opacity: CGFloat
}

// 좋아요 탭 카드 이미지 → 액티비티 상세 hero 이미지로 이어지는 hero transition을 위한 namespace.
// MainView가 @Namespace로 발급해 환경에 주입하고, LikedActivityCard와 ActivityDetailView가
// 같은 namespace로 matchedGeometryEffect를 걸어 자연스러운 확대 트랜지션을 그린다.
private struct LikesHeroNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var likesHeroNamespace: Namespace.ID? {
        get { self[LikesHeroNamespaceKey.self] }
        set { self[LikesHeroNamespaceKey.self] = newValue }
    }
}

extension View {
    // hero transition을 위한 matchedGeometryEffect를 namespace가 있는 경우에만 적용한다.
    @ViewBuilder
    func likesHeroMatched(activityId: String, namespace: Namespace.ID?) -> some View {
        if let namespace {
            self.matchedGeometryEffect(
                id: "likes-hero-\(activityId)",
                in: namespace
            )
        } else {
            self
        }
    }
}
