//
//  ReviewComposeView.swift
//  Ditto
//
//  Created by Codex on 5/5/26.
//

import PhotosUI
import SwiftUI
import UIKit

// 리뷰 작성/수정 모드를 구분한다.
// - .create: 새 리뷰 — orderCode 필요 (서버 검증)
// - .edit: 기존 리뷰 수정 — prefill로 별점/본문/이미지 채움
enum ReviewComposeMode: Equatable {
    case create(orderCode: String)
    case edit(reviewId: String, prefill: ReviewResponseDTO)
}

struct ReviewComposeView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ReviewComposeViewModel
    @State private var pickerSelection: [PhotosPickerItem] = []
    @State private var didApplyPrefill = false
    // 본문 TextField 포커스 — 키보드 툴바의 "완료" 버튼이 이 값을 false로 바꿔 키보드를 내린다.
    @FocusState private var isContentFocused: Bool

    private let mode: ReviewComposeMode
    private let authManager: any AuthManaging
    let onCompleted: () -> Void

    init(
        activityId: String,
        mode: ReviewComposeMode,
        authManager: any AuthManaging,
        onCompleted: @escaping () -> Void
    ) {
        self.mode = mode
        self.authManager = authManager
        self.onCompleted = onCompleted
        _viewModel = State(
            initialValue: ReviewComposeViewModel(activityId: activityId, authManager: authManager)
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    ReviewComposeRatingPicker(rating: $viewModel.rating)

                    ReviewComposeContentField(text: $viewModel.content, isFocused: $isContentFocused)

                    ReviewComposeAttachmentGrid(
                        imagePaths: viewModel.uploadedImagePaths,
                        isUploading: viewModel.isUploadingImage,
                        pickerSelection: $pickerSelection,
                        imageRequestProvider: imageRequest
                    ) { index in
                        viewModel.removeUploadedImage(at: index)
                    }

                    if let message = viewModel.message {
                        Text(message)
                            .font(MainScreenTypography.timestamp)
                            .foregroundStyle(Color(red: 0.72, green: 0.18, blue: 0.14))
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(MainScreenPalette.background.ignoresSafeArea())
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                        .disabled(viewModel.isSubmitting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if viewModel.isSubmitting {
                            ProgressView()
                        } else {
                            Text(submitButtonTitle)
                        }
                    }
                    .disabled(!canSubmit)
                }

                // 본문 TextField가 axis: .vertical이라 return은 줄바꿈으로 동작 → 키보드 내릴 별도 버튼 필요.
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("완료") { isContentFocused = false }
                }
            }
        }
        .onChange(of: pickerSelection) { _, items in
            handlePickerChange(items)
        }
        .task {
            applyPrefillIfNeeded()
        }
    }

    private var navigationTitle: String {
        switch mode {
        case .create: return "리뷰 작성"
        case .edit: return "리뷰 수정"
        }
    }

    private var submitButtonTitle: String {
        switch mode {
        case .create: return "등록"
        case .edit: return "저장"
        }
    }

    private var canSubmit: Bool {
        guard !viewModel.isSubmitting, !viewModel.isUploadingImage else { return false }
        let trimmed = viewModel.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && (1...5).contains(viewModel.rating)
    }

    private func applyPrefillIfNeeded() {
        guard !didApplyPrefill else { return }
        didApplyPrefill = true
        if case .edit(_, let review) = mode {
            viewModel.prefill(from: review)
        }
    }

    private func submit() async {
        let success: Bool
        switch mode {
        case .create(let orderCode):
            success = await viewModel.submit(orderCode: orderCode)
        case .edit(let reviewId, _):
            success = await viewModel.update(reviewId: reviewId)
        }

        if success {
            onCompleted()
            dismiss()
        }
    }

    private func handlePickerChange(_ items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }

        Task {
            for item in items {
                guard let raw = try? await item.loadTransferable(type: Data.self) else {
                    continue
                }
                // 사진 라이브러리는 HEIC를 그대로 내려주는 일이 많아 image/jpeg로 재인코딩한다.
                let data: Data
                let mimeType: String
                if let image = UIImage(data: raw),
                   let jpeg = image.jpegData(compressionQuality: 0.8) {
                    data = jpeg
                    mimeType = "image/jpeg"
                } else {
                    data = raw
                    mimeType = "image/jpeg"
                }
                let filename = "review-\(UUID().uuidString).jpg"
                _ = await viewModel.uploadImage(filename: filename, mimeType: mimeType, data: data)
            }
            pickerSelection = []
        }
    }

    private func imageRequest(for path: String) -> URLRequest? {
        guard let configuration = try? AppConfiguration() else { return nil }
        return ActivityFormatting.makeImageRequest(
            from: path,
            configuration: configuration,
            accessToken: authManager.tokens?.accessToken
        )
    }
}

// MARK: - Sub views

private struct ReviewComposeRatingPicker: View {
    @Binding var rating: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("별점")
                .font(MainScreenTypography.sectionTitle)
                .foregroundStyle(MainScreenPalette.textPrimary)

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        rating = value
                    } label: {
                        Image(systemName: value <= rating ? "star.fill" : "star")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(MainScreenPalette.primaryBlue)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(value)점")
                }

                Spacer()

                Text("\(rating) / 5")
                    .font(MainScreenTypography.body)
                    .foregroundStyle(MainScreenPalette.textSecondary)
            }
        }
    }
}

private struct ReviewComposeContentField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("내용")
                .font(MainScreenTypography.sectionTitle)
                .foregroundStyle(MainScreenPalette.textPrimary)

            TextField("리뷰 내용을 입력해 주세요", text: $text, axis: .vertical)
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textPrimary)
                .lineLimit(5...12)
                .focused($isFocused)
                .padding(12)
                .background(
                    MainScreenPalette.surface,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(MainScreenPalette.border, lineWidth: 1)
                )
        }
    }
}

private struct ReviewComposeAttachmentGrid: View {
    let imagePaths: [String]
    let isUploading: Bool
    @Binding var pickerSelection: [PhotosPickerItem]
    let imageRequestProvider: (String) -> URLRequest?
    let onRemove: (Int) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("사진")
                    .font(MainScreenTypography.sectionTitle)
                    .foregroundStyle(MainScreenPalette.textPrimary)

                if isUploading {
                    ProgressView()
                        .scaleEffect(0.7)
                }

                Spacer()

                Text("\(imagePaths.count)/4")
                    .font(MainScreenTypography.timestamp)
                    .foregroundStyle(MainScreenPalette.textSecondary)

                // 4장 한도 도달 시엔 picker를 노출하지 않는다.
                if imagePaths.count < 4 {
                    PhotosPicker(
                        selection: $pickerSelection,
                        maxSelectionCount: 4 - imagePaths.count,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text("추가")
                                .font(MainScreenTypography.timestamp)
                        }
                        .foregroundStyle(MainScreenPalette.primaryBlue)
                    }
                    .accessibilityLabel("사진 추가")
                }
            }

            if imagePaths.isEmpty {
                Text("최대 4장까지 첨부할 수 있어요.")
                    .font(MainScreenTypography.timestamp)
                    .foregroundStyle(MainScreenPalette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(imagePaths.enumerated()), id: \.offset) { index, path in
                        ReviewComposeThumbnail(request: imageRequestProvider(path)) {
                            onRemove(index)
                        }
                    }
                }
            }
        }
    }
}

private struct ReviewComposeThumbnail: View {
    let request: URLRequest?
    let onRemove: () -> Void

    @Environment(\.imageLoader) private var imageLoader
    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if let request, !didFail {
                    Color(MainScreenPalette.border)
                        .task(id: request.url?.absoluteString) {
                            await load(request)
                        }
                } else {
                    Image(systemName: "photo")
                        .font(.system(size: 18))
                        .foregroundStyle(MainScreenPalette.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(MainScreenPalette.border)
                }
            }
            .aspectRatio(1, contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white, Color.black.opacity(0.6))
            }
            .buttonStyle(.plain)
            .padding(4)
            .accessibilityLabel("사진 삭제")
        }
    }

    private func load(_ request: URLRequest) async {
        do {
            // 정사각 썸네일 표시 크기 기준으로 다운샘플링
            let pointSize = CGSize(width: 120, height: 120)
            // 환경에 인증 로더가 주입되어 있으면 토큰 만료(419) 자동 갱신 흐름을 탄다.
            let loaded: UIImage
            if let imageLoader {
                loaded = try await imageLoader.loadImage(request, pointSize: pointSize)
            } else {
                loaded = try await RemoteImageLoader.load(request: request, pointSize: pointSize)
            }
            image = loaded
        } catch {
            didFail = true
        }
    }
}
