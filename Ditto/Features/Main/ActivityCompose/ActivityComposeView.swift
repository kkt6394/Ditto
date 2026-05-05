//
//  ActivityComposeView.swift
//  Ditto
//
//  Created by Codex on 5/5/26.
//

import SwiftUI

struct ActivityComposeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ActivityComposeViewModel

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
            VStack(alignment: .leading, spacing: 18) {
                placeholderCard

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

    // 섹션 컴포넌트는 후속 커밋에서 차례로 추가된다(기본정보 → 미디어 → 위치 → 일정 → 가격/제약).
    private var placeholderCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("폼 섹션은 다음 커밋에서 추가됩니다.")
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textPrimary)
            Text("이번 커밋에는 화면 컨테이너와 진입점만 포함됩니다.")
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textSecondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MainScreenPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MainScreenPalette.border, lineWidth: 1)
        )
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
}
