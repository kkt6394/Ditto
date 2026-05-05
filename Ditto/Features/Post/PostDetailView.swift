//
//  PostDetailView.swift
//  Ditto
//
//  Created by Codex on 5/5/26.
//

import SwiftUI
import UIKit

struct PostDetailView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: PostDetailViewModel
    @State private var commentViewModel: PostCommentViewModel

    @State private var commentText = ""
    @State private var replyTarget: PostCommentResponseDTO?
    @State private var editingTarget: PostCommentEditTarget?
    @State private var deletingTarget: PostCommentEditTarget?
    @State private var editSubmitMessage: String?
    @FocusState private var isComposerFocused: Bool

    init(postId: String, authManager: any AuthManaging) {
        _viewModel = State(initialValue: PostDetailViewModel(postId: postId, authManager: authManager))
        _commentViewModel = State(initialValue: PostCommentViewModel(postId: postId, authManager: authManager))
    }

    var body: some View {
        VStack(spacing: 0) {
            navigationBar

            content
        }
        .background(MainScreenPalette.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: viewModel.postId) {
            await viewModel.load()
        }
        .task {
            // 댓글 작성/수정/삭제 후 포스트 상세를 다시 불러와 화면을 갱신한다.
            commentViewModel.didMutate = { [weak vm = viewModel] in
                await vm?.load()
            }
        }
        .sheet(item: $editingTarget) { target in
            PostCommentEditSheet(
                target: target,
                isSubmitting: commentViewModel.isMutating,
                errorMessage: editSubmitMessage
            ) { newContent in
                Task {
                    await submitEdit(target: target, content: newContent)
                }
            }
        }
        .alert("댓글을 삭제할까요?", isPresented: deletePresentationBinding) {
            Button("취소", role: .cancel) {
                deletingTarget = nil
            }
            Button("삭제", role: .destructive) {
                if let target = deletingTarget {
                    Task { await submitDelete(target: target) }
                }
            }
        } message: {
            Text("삭제한 댓글은 복구할 수 없습니다.")
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.post == nil {
            PostDetailStateView(title: "포스트를 불러오는 중입니다.", systemName: "arrow.clockwise")
                .frame(maxHeight: .infinity)
        } else if let post = viewModel.post {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    bodyContent(for: post)
                        .padding(.bottom, 24)
                }

                PostCommentComposer(
                    text: $commentText,
                    replyTargetNick: replyTarget?.creator.nick,
                    isSubmitting: commentViewModel.isMutating,
                    onSubmit: {
                        Task { await submitComment() }
                    },
                    onCancelReply: {
                        replyTarget = nil
                    }
                )
            }
        } else {
            PostDetailStateView(
                title: viewModel.message ?? "포스트를 확인할 수 없습니다.",
                systemName: "exclamationmark.circle"
            )
            .frame(maxHeight: .infinity)
        }
    }

    private func bodyContent(for post: PostResponseDTO) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            PostDetailHeroSection(imagePaths: post.files) { path in
                viewModel.imageRequest(for: path)
            }

            postMetadataSection(for: post)
                .padding(.horizontal, 20)

            Divider()
                .overlay(MainScreenPalette.border)
                .padding(.horizontal, 20)

            commentSection(for: post)
                .padding(.horizontal, 20)
        }
    }

    private func postMetadataSection(for post: PostResponseDTO) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            PostDetailAuthorRow(
                nick: post.creator.nick,
                timeText: PostCommentTimeFormatter.relative(from: post.createdAt),
                profileImageRequest: viewModel.imageRequest(for: post.creator.profileImage)
            )

            Text(post.title)
                .font(MainFont.paperlogyBlack(size: 22))
                .foregroundStyle(MainScreenPalette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            Text(post.content)
                .font(MainScreenTypography.postBody)
                .foregroundStyle(MainScreenPalette.textSecondary)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)

            PostDetailMetaRow(
                location: post.country,
                category: post.activity?.title ?? post.category
            )

            PostDetailLikeButton(
                isLiked: post.isLike,
                likeCount: Int(post.likeCount),
                isMutating: viewModel.isMutating
            ) {
                Task { await viewModel.toggleLike() }
            }
        }
    }

    private func commentSection(for post: PostResponseDTO) -> some View {
        PostCommentSection(
            comments: post.comments,
            currentUserId: viewModel.currentUserId,
            mutationMessage: commentViewModel.message,
            imageRequestProvider: { viewModel.imageRequest(for: $0) },
            onReply: { comment in
                replyTarget = comment
                isComposerFocused = true
            },
            onEdit: { target in
                editSubmitMessage = nil
                editingTarget = target
            },
            onDelete: { target in
                deletingTarget = target
            }
        )
    }

    private var navigationBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("포스트")
                .font(MainScreenTypography.brand)
                .foregroundStyle(MainScreenPalette.primaryBlue)

            Spacer()

            // 좌측 뒤로 가기 버튼과 시각적 균형을 맞추기 위한 placeholder.
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 4)
        .frame(height: 44)
        .background(MainScreenPalette.background)
    }

    private var deletePresentationBinding: Binding<Bool> {
        Binding(
            get: { deletingTarget != nil },
            set: { newValue in
                if !newValue {
                    deletingTarget = nil
                }
            }
        )
    }

    private func submitComment() async {
        let success = await commentViewModel.create(
            content: commentText,
            parentCommentId: replyTarget?.commentId
        )

        if success {
            commentText = ""
            replyTarget = nil
            isComposerFocused = false
        }
    }

    private func submitEdit(target: PostCommentEditTarget, content: String) async {
        editSubmitMessage = nil
        let success = await commentViewModel.update(
            commentId: target.commentId,
            content: content
        )

        if success {
            editingTarget = nil
        } else {
            editSubmitMessage = commentViewModel.message
        }
    }

    private func submitDelete(target: PostCommentEditTarget) async {
        await commentViewModel.delete(commentId: target.commentId)
        deletingTarget = nil
    }
}

// MARK: - Sub views

private struct PostDetailHeroSection: View {
    let imagePaths: [String]
    let imageRequestProvider: (String) -> URLRequest?

    var body: some View {
        if imagePaths.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(imagePaths.enumerated()), id: \.offset) { _, path in
                        PostDetailRemoteImage(request: imageRequestProvider(path))
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

private struct PostDetailRemoteImage: View {
    let request: URLRequest?
    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
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
                    .font(.system(size: 24))
                    .foregroundStyle(MainScreenPalette.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(MainScreenPalette.border)
            }
        }
        .frame(width: 280, height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func load(_ request: URLRequest) async {
        do {
            // 280×200 표시 크기로 다운샘플링
            let loaded = try await RemoteImageLoader.load(
                request: request,
                pointSize: CGSize(width: 280, height: 200)
            )
            image = loaded
        } catch {
            didFail = true
        }
    }
}

private struct PostDetailAuthorRow: View {
    let nick: String
    let timeText: String
    let profileImageRequest: URLRequest?

    var body: some View {
        HStack(spacing: 10) {
            PostDetailProfileImage(request: profileImageRequest)

            VStack(alignment: .leading, spacing: 2) {
                Text(nick)
                    .font(MainFont.pretendard(.bold, size: 14))
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .lineLimit(1)

                Text(timeText)
                    .font(MainScreenTypography.timestamp)
                    .foregroundStyle(MainScreenPalette.textSecondary)
            }

            Spacer()
        }
    }
}

private struct PostDetailProfileImage: View {
    let request: URLRequest?
    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
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
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(MainScreenPalette.textSecondary)
            }
        }
        .frame(width: 40, height: 40)
        .clipShape(Circle())
    }

    private func load(_ request: URLRequest) async {
        do {
            // 40×40 프로필 표시 크기로 다운샘플링
            let loaded = try await RemoteImageLoader.load(
                request: request,
                pointSize: CGSize(width: 40, height: 40)
            )
            image = loaded
        } catch {
            didFail = true
        }
    }
}

private struct PostDetailMetaRow: View {
    let location: String
    let category: String

    var body: some View {
        HStack(spacing: 8) {
            PostDetailChip(text: location, systemName: "location.fill")
            PostDetailChip(text: category, systemName: nil)
            Spacer()
        }
    }
}

private struct PostDetailChip: View {
    let text: String
    let systemName: String?

    var body: some View {
        HStack(spacing: 4) {
            if let systemName {
                Image(systemName: systemName)
                    .font(.system(size: 10, weight: .semibold))
            }

            Text(text)
                .lineLimit(1)
        }
        .font(MainScreenTypography.chip)
        .foregroundStyle(MainScreenPalette.primaryBlue)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(
            MainScreenPalette.background,
            in: RoundedRectangle(cornerRadius: 4, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .stroke(MainScreenPalette.borderBlue, lineWidth: 1)
        )
    }
}

private struct PostDetailLikeButton: View {
    let isLiked: Bool
    let likeCount: Int
    let isMutating: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        isLiked ? Color(red: 1.0, green: 0.38, blue: 0.52) : MainScreenPalette.textSecondary
                    )

                Text("\(likeCount)")
                    .font(MainScreenTypography.action)
                    .foregroundStyle(MainScreenPalette.textPrimary)
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(
                MainScreenPalette.background,
                in: Capsule()
            )
            .overlay(Capsule().stroke(MainScreenPalette.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(isMutating)
        .accessibilityLabel(isLiked ? "좋아요 취소" : "좋아요")
    }
}

private struct PostDetailStateView: View {
    let title: String
    let systemName: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemName)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(MainScreenPalette.primaryBlue)

            Text(title)
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }
}
