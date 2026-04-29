//
//  PostComposeView.swift
//  Ditto
//
//  Created by Codex on 4/29/26.
//

import PhotosUI
import SwiftUI

struct PostComposeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: PostComposeViewModel
    @State private var pickerSelection: [PhotosPickerItem] = []
    @State private var isPresentingActivityPicker = false

    let onSubmitted: () -> Void

    init(
        initialContext: PostComposeInitialContext,
        authManager: any AuthManaging,
        onSubmitted: @escaping () -> Void
    ) {
        _viewModel = State(
            initialValue: PostComposeViewModel(initialContext: initialContext, authManager: authManager)
        )
        self.onSubmitted = onSubmitted
    }

    var body: some View {
        VStack(spacing: 0) {
            PostComposeNavigationBar(
                canSubmit: viewModel.canSubmit,
                isSubmitting: viewModel.isSubmitting,
                cancelAction: { dismiss() },
                submitAction: handleSubmit
            )

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    PostComposeChipPicker(
                        title: "국가",
                        options: viewModel.countryOptions,
                        selection: $viewModel.country
                    )

                    PostComposeActivityRow(
                        activity: viewModel.selectedActivity,
                        pickAction: { isPresentingActivityPicker = true },
                        clearAction: { viewModel.selectActivity(nil) }
                    )

                    PostComposeTitleField(text: $viewModel.title)

                    PostComposeContentField(text: $viewModel.content)

                    PostComposeAttachmentGrid(
                        attachments: viewModel.attachments,
                        pickerSelection: $pickerSelection
                    ) {
                        viewModel.removeAttachment($0)
                    }

                    PostComposeLocationToggle(
                        useCurrentLocation: $viewModel.useCurrentLocation,
                        coordinate: locationCoordinate
                    )

                    if let message = viewModel.formMessage {
                        PostComposeMessageBanner(message: message)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 36)
            }
        }
        .background(MainScreenPalette.background.ignoresSafeArea())
        .onChange(of: pickerSelection) { _, items in
            handlePickerChange(items)
        }
        .sheet(isPresented: $isPresentingActivityPicker) {
            PostComposeActivityPickerSheet(viewModel: viewModel)
        }
    }

    private var locationCoordinate: UserCoordinate? {
        viewModel.coordinate
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

    private func handlePickerChange(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }

        Task {
            var datas: [Data] = []
            for item in items {
                guard let raw = try? await item.loadTransferable(type: Data.self) else {
                    continue
                }
                // 사진 라이브러리는 HEIC을 그대로 내려주는 일이 많다.
                // 서버에는 image/jpeg로 보내므로 실제 바이트도 JPEG로 재인코딩해 헤더와 본문을 일치시킨다.
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

struct PostComposeActivityPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: PostComposeViewModel
    @State private var keyword: String = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                searchField

                categoryChips

                if viewModel.isSearchingActivities {
                    ProgressView().padding(.top, 24)
                } else if viewModel.activityCandidates.isEmpty {
                    emptyState
                } else {
                    candidateList
                }

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .background(MainScreenPalette.background.ignoresSafeArea())
            .navigationTitle("액티비티 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .task {
                if viewModel.activityCandidates.isEmpty {
                    await viewModel.loadActivitiesByCategory()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(categoryOptions, id: \.id) { option in
                    let isSelected = option.value == viewModel.activityCategoryFilter

                    Button {
                        keyword = ""
                        Task { await viewModel.selectActivityCategory(option.value) }
                    } label: {
                        Text(option.title)
                            .font(MainScreenTypography.category)
                            .foregroundStyle(
                                isSelected
                                    ? MainScreenPalette.primaryBlue
                                    : MainScreenPalette.textSecondary
                            )
                            .padding(.horizontal, 14)
                            .frame(height: 32)
                            .background(
                                Capsule().fill(
                                    isSelected
                                        ? MainScreenPalette.primaryBlueSoft
                                        : MainScreenPalette.surface
                                )
                            )
                            .overlay(
                                Capsule().stroke(
                                    isSelected ? MainScreenPalette.borderBlue : MainScreenPalette.border,
                                    lineWidth: 1
                                )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var categoryOptions: [CategoryOption] {
        [CategoryOption(id: "all", title: "전체", value: nil)] +
        MainCategoryFilter.samples.map { CategoryOption(id: $0.id, title: $0.title, value: $0.title) }
    }

    private struct CategoryOption: Identifiable {
        let id: String
        let title: String
        let value: String?
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(MainScreenPalette.textSecondary)

            TextField("액티비티 제목 검색", text: $keyword)
                .submitLabel(.search)
                .onSubmit { triggerSearch() }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MainScreenPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MainScreenPalette.border, lineWidth: 1)
        )
    }

    private var candidateList: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(viewModel.activityCandidates) { candidate in
                    Button {
                        viewModel.selectActivity(candidate)
                        dismiss()
                    } label: {
                        candidateRow(candidate)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func candidateRow(_ candidate: PostComposeActivityCandidate) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(candidate.title)
                    .font(MainScreenTypography.postTitle)
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(metaText(for: candidate))
                    .font(MainScreenTypography.bodyCompact)
                    .foregroundStyle(MainScreenPalette.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(MainScreenPalette.textMuted)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 60)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MainScreenPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MainScreenPalette.border, lineWidth: 1)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(MainScreenPalette.textMuted)
            Text(viewModel.formMessage ?? "검색어를 입력하면 액티비티 목록이 표시됩니다.")
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 36)
        .frame(maxWidth: .infinity)
    }

    private func metaText(for candidate: PostComposeActivityCandidate) -> String {
        [candidate.country, candidate.category]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func triggerSearch() {
        viewModel.updateActivitySearchKeyword(keyword)
        Task { await viewModel.searchActivities() }
    }
}
