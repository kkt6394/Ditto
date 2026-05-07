//
//  ReceiptExportViewModel.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import Foundation
import Observation
import UIKit

// 단건 액티비티 추억 PDF의 ViewModel. 활동 리포트와 달리 scope 선택 단계가 없다.
// 진입 직후 액티비티 이미지를 백그라운드에서 다운로드하고, markup → rendering → ready 순으로 진행.
@MainActor
@Observable
final class ReceiptExportViewModel {
    enum Phase: Equatable {
        case loadingImage
        case markup
        case rendering
        case ready(URL)
        case failed(String)
    }

    private(set) var phase: Phase = .loadingImage
    var signatureImage: UIImage?

    private let activityTitle: String
    private let category: String?
    private let totalPrice: Int
    private let paidAt: String
    private let orderCode: String
    private let thumbnailPath: String?
    private let imageRequestBuilder: (String) -> URLRequest?

    // imageLoader는 SwiftUI 환경에서 와야 해서 init이 아닌 외부 setter로 주입한다.
    var imageLoader: (any AuthenticatedImageLoading)?

    private var activityImage: UIImage?

    init(
        activityTitle: String,
        category: String?,
        totalPrice: Int,
        paidAt: String,
        orderCode: String,
        thumbnailPath: String?,
        imageRequestBuilder: @escaping (String) -> URLRequest?
    ) {
        self.activityTitle = activityTitle
        self.category = category
        self.totalPrice = totalPrice
        self.paidAt = paidAt
        self.orderCode = orderCode
        self.thumbnailPath = thumbnailPath
        self.imageRequestBuilder = imageRequestBuilder
    }

    func bootstrap() async {
        activityImage = await loadActivityImage()
        phase = .markup
    }

    func makeReceipt() async {
        phase = .rendering
        let snapshot = ReceiptPDFSnapshot(
            activityTitle: activityTitle,
            category: category,
            totalPrice: totalPrice,
            paidAt: paidAt,
            activityImage: activityImage,
            signatureOverlay: signatureImage
        )
        let fileName = PDFFileNaming.receipt(orderCode: orderCode)
        do {
            let url = try await Task.detached(priority: .userInitiated) {
                let directory = try PDFFileNaming.temporaryDirectory()
                let fileURL = directory.appendingPathComponent(fileName)
                try ReceiptPDFRenderer(snapshot: snapshot).render(to: fileURL)
                return fileURL
            }.value
            phase = .ready(url)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func loadActivityImage() async -> UIImage? {
        guard let thumbnailPath, !thumbnailPath.isEmpty,
              let request = imageRequestBuilder(thumbnailPath) else {
            return nil
        }
        let target = CGSize(width: 600, height: 400)
        do {
            if let imageLoader {
                return try await imageLoader.loadImage(request, pointSize: target)
            }
            return try await RemoteImageLoader.load(request: request, pointSize: target)
        } catch {
            return nil
        }
    }
}
