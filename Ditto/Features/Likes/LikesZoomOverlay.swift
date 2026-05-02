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

// 좋아요 카드에서 이미 로드된 UIImage를 zoom 오버레이가 즉시 사용할 수 있도록
// activityId 기준으로 보관하는 메모리 캐시. zoom 시작 직전 카드 측에서 store하고
// LikesZoomImage가 가장 먼저 이 캐시를 조회한다.
//
// NSCache 기반으로 두 가지 경계를 둔다:
// 1) countLimit — 항목 수 상한. 좋아요 페이지네이션이 많아져도 무한 누적되지 않는다.
// 2) totalCostLimit — 바이트 합산 상한. 이미지가 커도 메모리 절대량을 보장한다.
// 추가로 시스템 메모리 압박 시 NSCache가 자동으로 일부 항목을 제거한다.
@MainActor
final class LikesActivityImageCache {
    static let shared = LikesActivityImageCache()

    private let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 40                // 최근 액티비티 40개까지만 유지
        cache.totalCostLimit = 80 * 1_024 * 1_024  // 약 80MB 상한
        return cache
    }()

    func image(for activityId: String) -> UIImage? {
        cache.object(forKey: activityId as NSString)
    }

    func store(_ image: UIImage, for activityId: String) {
        // 비용 = 픽셀 수 × 4바이트(BGRA). totalCostLimit과 비교해 자동 evict한다.
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: activityId as NSString, cost: cost)
    }

    /// 좋아요 탭에서 벗어나거나 메모리 회수가 필요할 때 외부에서 호출한다.
    func clearAll() {
        cache.removeAllObjects()
    }
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
    let activityId: String
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

            LikesZoomImage(activityId: activityId, request: imageRequest)
                .frame(width: currentWidth, height: currentHeight)
                .clipShape(RoundedRectangle(cornerRadius: currentCornerRadius, style: .continuous))
                .offset(x: currentX, y: currentY)
        }
        .allowsHitTesting(false)
        .transition(.opacity)
        .task {
            // .task는 view 마운트 시 안정적으로 한 번 실행된다. 첫 frame이 source rect로
            // 충분히 그려진 뒤 withAnimation으로 isExpanded를 켜 SwiftUI가
            // frame/offset/cornerRadius를 spring으로 보간한다.
            try? await Task.sleep(for: .milliseconds(40))
            withAnimation(.spring(response: 0.55, dampingFraction: 0.78)) {
                isExpanded = true
            }
        }
    }
}

// zoom 오버레이용 경량 이미지 뷰.
// LikesActivityImageCache를 우선 조회해 카드에서 이미 로드된 UIImage를 즉시 보여주고,
// 캐시가 비어 있으면 fallback으로 URLSession 호출을 시도한다.
private struct LikesZoomImage: View {
    let activityId: String
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
            if let cached = LikesActivityImageCache.shared.image(for: activityId) {
                remoteImage = cached
                return
            }
            guard let request, remoteImage == nil else { return }
            // 줌 오버레이 표시 크기 = 화면 전체 → 화면 크기 기준 다운샘플링
            let zoomSize = UIScreen.main.bounds.size
            if let img = try? await RemoteImageLoader.load(
                request: request,
                pointSize: zoomSize
            ) {
                remoteImage = img
                LikesActivityImageCache.shared.store(img, for: activityId)
            }
        }
    }
}
