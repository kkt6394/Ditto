//
//  LikesZoomOverlay.swift
//  Ditto
//
//  Created by Codex on 5/1/26.
//

import SwiftUI
import UIKit

// zoom 오버레이의 source(좋아요 카드 이미지)와 destination(상세 화면 hero 이미지)
// 좌표를 한 PreferenceKey로 묶어 publish한다. activityId 별로 source/destination 한 쌍.
struct LikesZoomAnchorPair {
    var source: Anchor<CGRect>?
    var destination: Anchor<CGRect>?
}

// 좋아요 탭에서 zoom 트랜지션이 활성화된 동안 true. ActivityDetailView가
// 이 값을 보고 본문(hero 이미지 아래)의 fade-in delay를 적용한다.
private struct LikesZoomActiveKey: EnvironmentKey {
    static let defaultValue: Bool = false
}

extension EnvironmentValues {
    var likesZoomActive: Bool {
        get { self[LikesZoomActiveKey.self] }
        set { self[LikesZoomActiveKey.self] = newValue }
    }
}

struct LikesZoomAnchorKey: PreferenceKey {
    static let defaultValue: [String: LikesZoomAnchorPair] = [:]

    static func reduce(value: inout Value, nextValue: () -> Value) {
        for (id, pair) in nextValue() {
            var existing = value[id] ?? LikesZoomAnchorPair()
            if let source = pair.source {
                existing.source = source
            }
            if let destination = pair.destination {
                existing.destination = destination
            }
            value[id] = existing
        }
    }
}

// 카드 → 상세 hero로 이미지가 확대되는 zoom 트랜지션 오버레이.
// MainView 최상단에서 NavigationStack 위에 그려져, push 슬라이드보다 위에 보인다.
// cleanup(zoomingActivityId reset)은 MainView에서 스케줄해 안전하게 처리한다.
struct LikesZoomOverlay: View {
    let imageRequest: URLRequest?
    let source: CGRect
    let destination: CGRect

    @State private var isExpanded = false

    private var currentWidth: CGFloat {
        max(isExpanded ? destination.width : source.width, 1)
    }

    private var currentHeight: CGFloat {
        max(isExpanded ? destination.height : source.height, 1)
    }

    private var currentX: CGFloat {
        isExpanded ? destination.minX : source.minX
    }

    private var currentY: CGFloat {
        isExpanded ? destination.minY : source.minY
    }

    private var currentCornerRadius: CGFloat {
        isExpanded ? 0 : 14
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear

            LikesZoomImage(request: imageRequest)
                .frame(width: currentWidth, height: currentHeight)
                .clipShape(RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous))
                .offset(x: currentX, y: currentY)
        }
        .allowsHitTesting(false)
        .transition(.opacity)
        .task {
            // .task는 view 마운트 시 안정적으로 한 번 실행된다. 한 frame 양보 후
            // withAnimation으로 isExpanded를 켜 SwiftUI가 frame/offset/cornerRadius를 보간한다.
            try? await Task.sleep(for: .milliseconds(16))
            withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                isExpanded = true
            }
        }
    }
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
