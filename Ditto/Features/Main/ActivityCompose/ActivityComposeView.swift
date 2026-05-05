//
//  ActivityComposeView.swift
//  Ditto
//
//  Created by Codex on 5/5/26.
//

import PhotosUI
import SwiftUI

struct ActivityComposeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ActivityComposeViewModel
    @State private var pickerSelection: [PhotosPickerItem] = []

    let onSubmitted: () -> Void

    init(
        mode: ActivityComposeMode,
        authManager: any AuthManaging,
        onSubmitted: @escaping () -> Void
    ) {
        _viewModel = State(
            initialValue: ActivityComposeViewModel(mode: mode, authManager: authManager)
        )
        self.onSubmitted = onSubmitted
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                ActivityComposeBasicSection(viewModel: viewModel)

                ActivityComposeMediaSection(
                    attachments: viewModel.attachments,
                    pickerSelection: $pickerSelection,
                    availableSlotCount: viewModel.availableSlotCount,
                    removeAction: { viewModel.removeAttachment($0) }
                )

                ActivityComposeLocationSection(viewModel: viewModel)

                pendingSectionsNotice

                if let message = viewModel.formMessage {
                    Text(message)
                        .font(MainScreenTypography.body)
                        .foregroundStyle(MainScreenPalette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 36)
        }
        .background(MainScreenPalette.background.ignoresSafeArea())
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .task { await viewModel.loadInitialDataIfNeeded() }
        .onChange(of: pickerSelection) { _, items in
            handlePickerChange(items)
        }
    }

    private var navigationTitle: String {
        switch viewModel.mode {
        case .create:
            return "액티비티 등록"
        case .edit:
            return "액티비티 수정"
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: handleSubmit) {
                if viewModel.isSubmitting {
                    ProgressView()
                } else {
                    Text("저장")
                        .font(MainScreenTypography.body)
                        .foregroundStyle(
                            viewModel.canSubmit
                                ? MainScreenPalette.primaryBlue
                                : MainScreenPalette.textSecondary
                        )
                }
            }
            .disabled(!viewModel.canSubmit || viewModel.isSubmitting)
        }
    }

    // 후속 섹션(일정/가격/제약)은 별도 커밋에서 추가된다.
    private var pendingSectionsNotice: some View {
        Text("일정·가격/제약 섹션은 다음 커밋에서 추가됩니다.")
            .font(MainScreenTypography.body)
            .foregroundStyle(MainScreenPalette.textSecondary)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func handleSubmit() {
        Task {
            let success = await viewModel.submit()
            if success {
                onSubmitted()
                dismiss()
            }
        }
    }

    // PostComposeView 패턴 — HEIC을 JPEG로 재인코딩해 헤더(image/jpeg)와 본문 일치를 보장한다.
    private func handlePickerChange(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }

        Task {
            var datas: [Data] = []
            for item in items {
                guard let raw = try? await item.loadTransferable(type: Data.self) else {
                    continue
                }
                if let image = UIImage(data: raw),
                   let jpeg = image.jpegData(compressionQuality: 0.8) {
                    datas.append(jpeg)
                } else {
                    datas.append(raw)
                }
            }
            viewModel.appendAttachments(datas)
            pickerSelection = []
        }
    }
}
