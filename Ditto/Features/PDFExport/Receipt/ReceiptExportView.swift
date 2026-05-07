//
//  ReceiptExportView.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import SwiftUI

// 단건 액티비티 추억 PDF Export 화면.
// loadingImage → markup → rendering → ready Phase 머신.
struct ReceiptExportView: View {
    let activityTitle: String
    let category: String?
    let totalPrice: Int
    let paidAt: String
    let orderCode: String
    let thumbnailPath: String?
    let imageRequestBuilder: (String) -> URLRequest?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.imageLoader) private var imageLoader
    @State private var viewModel: ReceiptExportViewModel

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
        _viewModel = State(initialValue: ReceiptExportViewModel(
            activityTitle: activityTitle,
            category: category,
            totalPrice: totalPrice,
            paidAt: paidAt,
            orderCode: orderCode,
            thumbnailPath: thumbnailPath,
            imageRequestBuilder: imageRequestBuilder
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            PDFExportNavigationBar(
                title: navigationTitle,
                onClose: { dismiss() },
                trailing: { trailingButton }
            )

            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MainScreenPalette.background.ignoresSafeArea())
        .task {
            // 환경 imageLoader를 ViewModel에 주입한 뒤 사진 다운로드 시작.
            viewModel.imageLoader = imageLoader
            await viewModel.bootstrap()
        }
    }

    private var navigationTitle: String {
        switch viewModel.phase {
        case .loadingImage: return "사진 준비 중"
        case .markup: return "추억 메모"
        case .rendering: return "PDF 만드는 중"
        case .ready: return "내 액티비티"
        case .failed: return "오류"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .loadingImage:
            loadingSection(message: "액티비티 사진을 받는 중입니다.")
        case .markup:
            markupSection
        case .rendering:
            loadingSection(message: "PDF를 만드는 중입니다.")
        case .ready(let url):
            previewSection(url: url)
        case .failed(let message):
            failedSection(message: message)
        }
    }

    @ViewBuilder
    private var markupSection: some View {
        VStack(spacing: 16) {
            Text("PDF 우하단에 들어갈 추억 메모를 적어보세요. 비워둬도 됩니다.")
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 12)

            PaperKitMarkupCanvasView(image: $viewModel.signatureImage)
                .background(MainScreenPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(MainScreenPalette.border, lineWidth: 1)
                )
                .padding(.horizontal, 20)

            Button {
                Task { await viewModel.makeReceipt() }
            } label: {
                Text("PDF 미리보기")
                    .font(MainFont.pretendard(.bold, size: 16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        MainScreenPalette.primaryBlue,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private func loadingSection(message: String) -> some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large)
            Text(message)
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func previewSection(url: URL) -> some View {
        let item = PDFShareItem(
            url: url,
            title: "Ditto · \(activityTitle)",
            subtitle: orderCode
        )
        return VStack(spacing: 12) {
            PDFPreviewView(url: url)
                .background(MainScreenPalette.surface)
                .padding(.horizontal, 12)

            ShareLink(item: item, preview: item.sharePreview) {
                Text("공유 / 저장")
                    .font(MainFont.pretendard(.bold, size: 16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        MainScreenPalette.primaryBlue,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private func failedSection(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(MainScreenPalette.textSecondary)
            Text(message)
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var trailingButton: some View {
        if case .markup = viewModel.phase, viewModel.signatureImage != nil {
            Button {
                viewModel.signatureImage = nil
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
        } else {
            Color.clear.frame(width: 44, height: 44)
        }
    }
}
