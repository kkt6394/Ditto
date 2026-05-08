//
//  PostDetailCommentComponents.swift
//  Ditto
//
//  Created by Codex on 5/5/26.
//

import SwiftUI
import UIKit

// MARK: - Section

// 포스트 상세 화면의 댓글 섹션. 댓글 + 대댓글(replies)을 한 번에 렌더링한다.
struct PostCommentSection: View {
    let comments: [PostCommentResponseDTO]
    let currentUserId: String?
    let mutationMessage: String?
    let imageRequestProvider: (String) -> URLRequest?
    let onReply: (PostCommentResponseDTO) -> Void
    let onEdit: (PostCommentEditTarget) -> Void
    let onDelete: (PostCommentEditTarget) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("댓글")
                    .font(MainScreenTypography.sectionTitle)
                    .foregroundStyle(MainScreenPalette.textPrimary)

                Text("\(totalCommentCount)")
                    .font(MainScreenTypography.timestamp)
                    .foregroundStyle(MainScreenPalette.textSecondary)
            }

            if comments.isEmpty {
                PostCommentStateCard(
                    title: "아직 작성된 댓글이 없습니다.",
                    systemName: "text.bubble"
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(comments, id: \.commentId) { comment in
                        commentBlock(comment)
                    }
                }
            }

            if let mutationMessage {
                Text(mutationMessage)
                    .font(MainScreenTypography.timestamp)
                    .foregroundStyle(Color(red: 0.72, green: 0.18, blue: 0.14))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var totalCommentCount: Int {
        comments.totalCommentCount
    }

    @ViewBuilder
    private func commentBlock(_ comment: PostCommentResponseDTO) -> some View {
        VStack(spacing: 8) {
            PostCommentCard(
                comment: comment,
                isMine: currentUserId == comment.creator.userId,
                imageRequestProvider: imageRequestProvider,
                onReply: { onReply(comment) },
                onEdit: {
                    onEdit(PostCommentEditTarget(
                        commentId: comment.commentId,
                        content: comment.content,
                        creatorNick: comment.creator.nick
                    ))
                },
                onDelete: {
                    onDelete(PostCommentEditTarget(
                        commentId: comment.commentId,
                        content: comment.content,
                        creatorNick: comment.creator.nick
                    ))
                }
            )

            ForEach(comment.replies, id: \.commentId) { reply in
                PostCommentReplyCard(
                    reply: reply,
                    isMine: currentUserId == reply.creator.userId,
                    imageRequestProvider: imageRequestProvider,
                    onEdit: {
                        onEdit(PostCommentEditTarget(
                            commentId: reply.commentId,
                            content: reply.content,
                            creatorNick: reply.creator.nick
                        ))
                    },
                    onDelete: {
                        onDelete(PostCommentEditTarget(
                            commentId: reply.commentId,
                            content: reply.content,
                            creatorNick: reply.creator.nick
                        ))
                    }
                )
                .padding(.leading, 32)
            }
        }
    }
}

// 댓글/대댓글의 수정·삭제 시 식별/표시에 필요한 최소 정보.
struct PostCommentEditTarget: Identifiable, Equatable {
    let commentId: String
    let content: String
    let creatorNick: String

    var id: String { commentId }
}

// MARK: - Cards

private struct PostCommentCard: View {
    let comment: PostCommentResponseDTO
    let isMine: Bool
    let imageRequestProvider: (String) -> URLRequest?
    let onReply: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PostCommentHeader(
                nick: comment.creator.nick,
                createdAt: comment.createdAt,
                profileImageRequest: comment.creator.profileImage.flatMap(imageRequestProvider),
                isMine: isMine,
                onEdit: onEdit,
                onDelete: onDelete
            )

            Text(comment.content)
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                onReply()
            } label: {
                Text("답글 달기")
                    .font(MainScreenTypography.action)
                    .foregroundStyle(MainScreenPalette.primaryBlue)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MainScreenPalette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(MainScreenPalette.border, lineWidth: 1)
        )
    }
}

private struct PostCommentReplyCard: View {
    let reply: CommentReplyResponseDTO
    let isMine: Bool
    let imageRequestProvider: (String) -> URLRequest?
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PostCommentHeader(
                nick: reply.creator.nick,
                createdAt: reply.createdAt,
                profileImageRequest: reply.creator.profileImage.flatMap(imageRequestProvider),
                isMine: isMine,
                onEdit: onEdit,
                onDelete: onDelete
            )

            Text(reply.content)
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MainScreenPalette.background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(MainScreenPalette.border, lineWidth: 1)
        )
    }
}

private struct PostCommentHeader: View {
    let nick: String
    let createdAt: String
    let profileImageRequest: URLRequest?
    let isMine: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            PostCommentProfileImage(request: profileImageRequest)

            VStack(alignment: .leading, spacing: 2) {
                Text(nick)
                    .font(MainFont.pretendard(.bold, size: 13))
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .lineLimit(1)

                Text(PostCommentTimeFormatter.relative(from: createdAt))
                    .font(MainScreenTypography.timestamp)
                    .foregroundStyle(MainScreenPalette.textSecondary)
            }

            Spacer()

            if isMine {
                Menu {
                    Button("수정", action: onEdit)
                    Button("삭제", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MainScreenPalette.textSecondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("내 댓글 메뉴")
            }
        }
    }
}

// MARK: - Composer

// 댓글/대댓글 작성용 하단 입력창. 답글 모드일 때 헤더에 대상 닉네임을 표시한다.
struct PostCommentComposer: View {
    @Binding var text: String
    let replyTargetNick: String?
    let isSubmitting: Bool
    let onSubmit: () -> Void
    let onCancelReply: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if let replyTargetNick {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(MainScreenPalette.primaryBlue)

                    Text("\(replyTargetNick)님에게 답글")
                        .font(MainScreenTypography.timestamp)
                        .foregroundStyle(MainScreenPalette.textSecondary)
                        .lineLimit(1)

                    Spacer()

                    Button {
                        onCancelReply()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(MainScreenPalette.textMuted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("답글 모드 해제")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    MainScreenPalette.primaryBlueSoft,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
            }

            HStack(alignment: .bottom, spacing: 10) {
                TextField(
                    replyTargetNick == nil ? "댓글을 입력해 주세요" : "답글을 입력해 주세요",
                    text: $text,
                    axis: .vertical
                )
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textPrimary)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    MainScreenPalette.background,
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(MainScreenPalette.border, lineWidth: 1)
                )
                .submitLabel(.send)
                .onSubmit(onSubmit)
                .disabled(isSubmitting)

                Button {
                    onSubmit()
                } label: {
                    Group {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 36, height: 36)
                    .background(
                        canSubmit ? MainScreenPalette.primaryBlue : MainScreenPalette.textMuted,
                        in: Circle()
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canSubmit)
                .accessibilityLabel("댓글 보내기")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(
            MainScreenPalette.surface
                .ignoresSafeArea(edges: .bottom)
        )
        .overlay(alignment: .top) {
            Divider().overlay(MainScreenPalette.border)
        }
    }

    private var canSubmit: Bool {
        !isSubmitting && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Helpers

private struct PostCommentProfileImage: View {
    let request: URLRequest?
    @Environment(\.imageLoader) private var imageLoader
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
        .frame(width: 32, height: 32)
        .clipShape(Circle())
    }

    private func load(_ request: URLRequest) async {
        do {
            // 32×32 프로필 표시 크기로 다운샘플링
            let pointSize = CGSize(width: 32, height: 32)
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

private struct PostCommentStateCard: View {
    let title: String
    let systemName: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(MainScreenPalette.primaryBlue)

            Text(title)
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(MainScreenPalette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(MainScreenPalette.border, lineWidth: 1)
        )
    }
}

// MARK: - Time formatting

// 댓글 createdAt(ISO8601 또는 서버 포맷)을 "방금 전 / N분 전 / N시간 전 / yyyy.MM.dd"로 변환한다.
enum PostCommentTimeFormatter {
    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fallbackFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let absoluteFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy.MM.dd"
        return formatter
    }()

    static func relative(from raw: String) -> String {
        let date = iso8601Formatter.date(from: raw)
            ?? fallbackFormatter.date(from: raw)

        guard let date else { return raw }

        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "방금 전"
        } else if interval < 3_600 {
            return "\(Int(interval / 60))분 전"
        } else if interval < 86_400 {
            return "\(Int(interval / 3_600))시간 전"
        } else if interval < 86_400 * 7 {
            return "\(Int(interval / 86_400))일 전"
        }

        return absoluteFormatter.string(from: date)
    }
}
