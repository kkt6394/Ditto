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
        .onAppear {
            // 초기 렌더는 source rect에서 시작. 다음 runloop에 withAnimation으로
            // isExpanded를 켜 SwiftUI가 frame/offset/cornerRadius를 spring으로 보간한다.
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                    isExpanded = true
                }
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
