//
//  ActivityReportExportView.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import SwiftUI

// 활동 리포트 PDF Export 화면.
// scopeSelection → loadingImages → markup → rendering → ready Phase 머신을 한 화면에서 굴린다.
struct ActivityReportExportView: View {
    let orders: [OrderReviewResponseDTO]
    let userDisplayName: String
    let imageRequestBuilder: (String) -> URLRequest?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.imageLoader) private var imageLoader
    @State private var viewModel: ActivityReportExportViewModel

    init(
        orders: [OrderReviewResponseDTO],
        userDisplayName: String = "Ditto 사용자",
        imageRequestBuilder: @escaping (String) -> URLRequest?
    ) {
        self.orders = orders
        self.userDisplayName = userDisplayName
        self.imageRequestBuilder = imageRequestBuilder
        _viewModel = State(initialValue: ActivityReportExportViewModel(
            orders: orders,
            userDisplayName: userDisplayName,
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
            // 환경 imageLoader를 viewModel로 주입한다 (init 시점엔 environment 못 받음).
            viewModel.imageLoader = imageLoader
        }
    }

    private var navigationTitle: String {
        switch viewModel.phase {
        case .scopeSelection: return "기간 선택"
        case .loadingImages: return "사진 준비 중"
        case .markup: return "표지 손글씨"
        case .rendering: return "PDF 만드는 중"
        case .ready: return "활동 리포트"
        case .failed: return "오류"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .scopeSelection:
            scopeSelectionSection
        case .loadingImages:
            loadingSection(message: "선택한 기간의 사진을 받는 중입니다.")
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
    private var scopeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("어느 기간으로 만들까요?")
                .font(MainFont.pretendard(.bold, size: 16))
                .foregroundStyle(MainScreenPalette.textPrimary)
                .padding(.horizontal, 20)
                .padding(.top, 12)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.availableScopes, id: \.self) { scope in
                        ScopeRow(
                            scope: scope,
                            isSelected: scope == viewModel.selectedScope
                        ) {
                            viewModel.selectedScope = scope
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }

            Button {
                Task { await viewModel.confirmScope() }
            } label: {
                Text("다음 (손글씨)")
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

    @ViewBuilder
    private var markupSection: some View {
        VStack(spacing: 16) {
            Text("표지 우하단에 들어갈 손글씨를 적어보세요. 비워둬도 됩니다.")
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.top, 12)

            PaperKitMarkupCanvasView(image: $viewModel.markupImage)
                .background(MainScreenPalette.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(MainScreenPalette.border, lineWidth: 1)
                )
                .padding(.horizontal, 20)

            Button {
                Task { await viewModel.makeReport() }
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
            title: "Ditto 활동 리포트 · \(viewModel.selectedScope.displayLabel)",
            subtitle: "\(userDisplayName)님의 활동 리포트"
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
        if case .markup = viewModel.phase, viewModel.markupImage != nil {
            Button {
                viewModel.markupImage = nil
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

// scope 한 줄. 선택 표시 + 라벨.
private struct ScopeRow: View {
    let scope: ActivityReportScope
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(scope.displayLabel)
                    .font(MainFont.pretendard(.medium, size: 15))
                    .foregroundStyle(MainScreenPalette.textPrimary)
                Spacer()
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(
                        isSelected
                            ? MainScreenPalette.primaryBlue
                            : MainScreenPalette.textMuted
                    )
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                MainScreenPalette.surface,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected
                            ? MainScreenPalette.primaryBlue
                            : MainScreenPalette.border,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
