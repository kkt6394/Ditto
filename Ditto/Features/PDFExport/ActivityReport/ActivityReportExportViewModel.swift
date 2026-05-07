//
//  ActivityReportExportViewModel.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class ActivityReportExportViewModel {
    enum Phase: Equatable {
        case scopeSelection
        case loadingImages
        case markup
        case rendering
        case ready(URL)
        case failed(String)
    }

    private(set) var phase: Phase = .scopeSelection
    private(set) var availableScopes: [ActivityReportScope] = []
    var selectedScope: ActivityReportScope = .all
    var markupImage: UIImage?

    private let allOrders: [OrderReviewResponseDTO]
    private let userDisplayName: String
    private let imageRequestBuilder: (String) -> URLRequest?

    // imageLoader는 SwiftUI 환경에서 와야 해서 init이 아닌 외부 setter로 주입한다.
    var imageLoader: (any AuthenticatedImageLoading)?

    // 이미지 미리 받아둔 결과. confirmScope에서 채우고 makeReport가 그대로 사용.
    private var filteredOrders: [OrderReviewResponseDTO] = []
    private var thumbnails: [String: UIImage] = [:]

    init(
        orders: [OrderReviewResponseDTO],
        userDisplayName: String,
        imageRequestBuilder: @escaping (String) -> URLRequest?
    ) {
        self.allOrders = orders
        self.userDisplayName = userDisplayName
        self.imageRequestBuilder = imageRequestBuilder
        self.availableScopes = ActivityReportScope.availableScopes(from: orders)
    }

    // scope 확정 → 필터 → 이미지 다운로드 → markup 단계로 넘어간다.
    func confirmScope() async {
        let filtered = ActivityReportScope.filter(allOrders, by: selectedScope)
        if filtered.isEmpty {
            phase = .failed("선택한 기간에 활동이 없습니다.")
            return
        }
        filteredOrders = filtered
        phase = .loadingImages
        thumbnails = await loadThumbnails(for: filtered)
        phase = .markup
    }

    // 표지 markup이 끝나고 미리보기로 넘어가는 단계.
    func makeReport() async {
        phase = .rendering
        let snapshot = ActivityReportSnapshot(
            userDisplayName: userDisplayName,
            generatedAt: Date(),
            scope: selectedScope,
            stats: ActivityReportAggregator.make(from: filteredOrders),
            orders: filteredOrders,
            thumbnails: thumbnails,
            markupOverlay: markupImage
        )
        let suffix = selectedScope.fileSuffix
        do {
            let url = try await Task.detached(priority: .userInitiated) {
                let directory = try PDFFileNaming.temporaryDirectory()
                let fileURL = directory.appendingPathComponent(
                    "Ditto_활동리포트_\(suffix).pdf"
                )
                try ActivityReportPDFRenderer(snapshot: snapshot).render(to: fileURL)
                return fileURL
            }.value
            phase = .ready(url)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    // 한 페이지 풀폭에 맞춘 220x220 다운샘플로 충분. 인증 실패한 항목은 placeholder 없이 빈 dict 키 누락.
    private func loadThumbnails(
        for orders: [OrderReviewResponseDTO]
    ) async -> [String: UIImage] {
        let targetSize = CGSize(width: 220, height: 220)

        return await withTaskGroup(of: (String, UIImage?).self) { group in
            for order in orders {
                group.addTask { [self] in
                    let image = await loadThumbnail(for: order, targetSize: targetSize)
                    return (order.orderId, image)
                }
            }
            var collected: [String: UIImage] = [:]
            for await (orderId, image) in group {
                if let image {
                    collected[orderId] = image
                }
            }
            return collected
        }
    }

    private func loadThumbnail(
        for order: OrderReviewResponseDTO,
        targetSize: CGSize
    ) async -> UIImage? {
        guard let firstThumbnail = order.activity.thumbnails.first,
              let request = imageRequestBuilder(firstThumbnail) else {
            return nil
        }
        do {
            if let imageLoader {
                return try await imageLoader.loadImage(request, pointSize: targetSize)
            }
            return try await RemoteImageLoader.load(request: request, pointSize: targetSize)
        } catch {
            return nil
        }
    }
}
