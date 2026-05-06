//
//  ChatRoomBubble.swift
//  Ditto
//
//  Created by Codex on 5/2/26.
//

import Foundation
import SwiftUI
import UIKit

// MARK: - Media Models

struct ChatMediaItem: Identifiable, Equatable {
    let id: String
    let path: String
    let thumbnailRequest: URLRequest?

    init(path: String, authManager: any AuthManaging) {
        self.id = path
        self.path = path
        if let configuration = try? AppConfiguration() {
            self.thumbnailRequest = ActivityFormatting.makeImageRequest(
                from: path,
                configuration: configuration,
                accessToken: authManager.tokens?.accessToken
            )
        } else {
            self.thumbnailRequest = nil
        }
    }
}

struct ChatPDFItem: Identifiable, Equatable {
    let id: String
    let path: String
    let downloadRequest: URLRequest?

    init(path: String, authManager: any AuthManaging) {
        self.id = path
        self.path = path
        if let configuration = try? AppConfiguration() {
            self.downloadRequest = ActivityFormatting.makeImageRequest(
                from: path,
                configuration: configuration,
                accessToken: authManager.tokens?.accessToken
            )
        } else {
            self.downloadRequest = nil
        }
    }

    var displayName: String {
        path.split(separator: "/").last.map(String.init) ?? path
    }
}

enum ChatMediaPresentation: Identifiable {
    case image(ChatMediaItem)
    case pdf(ChatPDFItem)

    var id: String {
        switch self {
        case .image(let item): return "image-" + item.id
        case .pdf(let item): return "pdf-" + item.id
        }
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatResponseDTO
    let isOutgoing: Bool
    let opponentNick: String
    let authManager: any AuthManaging
    let status: ChatMessageStatus
    let onSelectMedia: (ChatMediaPresentation) -> Void
    let onTapFailed: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isOutgoing {
                Spacer(minLength: 52)
                timeText
                outgoingColumn
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(message.sender.nick.isEmpty ? opponentNick : message.sender.nick)
                        .font(MainScreenTypography.timestamp)
                        .foregroundStyle(MainScreenPalette.textSecondary)

                    HStack(alignment: .bottom, spacing: 6) {
                        bubbleColumn(alignment: .leading)
                        timeText
                    }
                }
                Spacer(minLength: 52)
            }
        }
        .frame(maxWidth: .infinity, alignment: isOutgoing ? .trailing : .leading)
    }

    // 보내는 메시지에만 sending/failed 상태가 발생하므로 outgoing 전용으로 묶는다.
    private var outgoingColumn: some View {
        VStack(alignment: .trailing, spacing: 4) {
            bubbleColumn(alignment: .trailing)
            statusFooter
        }
        .opacity(status == .sending ? 0.6 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            // 실패 상태에서만 탭 액션을 받는다. sent/sending 시점에는 무시한다.
            guard status == .failed else { return }
            onTapFailed()
        }
    }

    @ViewBuilder
    private var statusFooter: some View {
        switch status {
        case .sending:
            Text("보내는 중...")
                .font(MainScreenTypography.timestamp)
                .foregroundStyle(MainScreenPalette.textSecondary)
        case .failed:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                Text("전송 실패 — 탭하여 다시 시도")
                    .font(MainScreenTypography.timestamp)
            }
            .foregroundStyle(Color(red: 0.72, green: 0.18, blue: 0.14))
        case .sent:
            EmptyView()
        }
    }

    private func bubbleColumn(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 6) {
            if !mediaItems.isEmpty {
                ChatMediaGrid(
                    items: mediaItems,
                    onSelect: onSelectMedia
                )
            }

            if !pdfItems.isEmpty {
                VStack(alignment: alignment, spacing: 4) {
                    ForEach(pdfItems) { pdf in
                        ChatPDFRow(item: pdf, isOutgoing: isOutgoing) {
                            onSelectMedia(.pdf(pdf))
                        }
                    }
                }
            }

            if hasDisplayableText {
                textBubble
            }
        }
    }

    private var textBubble: some View {
        Text(message.content)
            .font(MainScreenTypography.body)
            .foregroundStyle(isOutgoing ? .white : MainScreenPalette.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: 260, alignment: .leading)
            .background(bubbleColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(strokeColor, lineWidth: status == .failed ? 1.5 : 1)
            )
    }

    private var strokeColor: Color {
        if status == .failed {
            return Color(red: 0.72, green: 0.18, blue: 0.14)
        }

        return isOutgoing ? Color.clear : MainScreenPalette.border
    }

    private var timeText: some View {
        Text(formattedTime)
            .font(MainScreenTypography.timestamp)
            .foregroundStyle(MainScreenPalette.textSecondary)
            .lineLimit(1)
            .padding(.bottom, 2)
    }

    private var bubbleColor: Color {
        isOutgoing ? MainScreenPalette.primaryBlue : MainScreenPalette.surface
    }

    /// 첨부만 보내는 메시지는 서버 정책상 content에 zero-width space(U+200B)를 채워 보낸다.
    /// 화면에서는 빈 텍스트 버블이 보이지 않도록 비가시 문자를 제거한 뒤 비어있으면 그리지 않는다.
    private var hasDisplayableText: Bool {
        let cleaned = message.content
            .replacingOccurrences(of: "\u{200B}", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return !cleaned.isEmpty
    }

    private var formattedTime: String {
        let date = Self.dateFormatter.date(from: message.createdAt)
            ?? Self.fallbackDateFormatter.date(from: message.createdAt)

        guard let date else { return "" }
        return Self.timeFormatter.string(from: date)
    }

    private var mediaItems: [ChatMediaItem] {
        message.files.compactMap { path in
            guard ActivityFormatting.isImagePath(path) else { return nil }
            return ChatMediaItem(path: path, authManager: authManager)
        }
    }

    private var pdfItems: [ChatPDFItem] {
        message.files.compactMap { path in
            guard path.lowercased().hasSuffix(".pdf") else { return nil }
            return ChatPDFItem(path: path, authManager: authManager)
        }
    }

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fallbackDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter
    }()
}

// MARK: - Chat Media Grid

struct ChatMediaGrid: View {
    let items: [ChatMediaItem]
    let onSelect: (ChatMediaPresentation) -> Void

    var body: some View {
        let displayItems = Array(items.prefix(4))

        switch displayItems.count {
        case 1:
            mediaTile(displayItems[0], width: 220, height: 220)
        case 2:
            HStack(spacing: 4) {
                mediaTile(displayItems[0], width: 130, height: 180)
                mediaTile(displayItems[1], width: 130, height: 180)
            }
        case 3:
            HStack(spacing: 4) {
                mediaTile(displayItems[0], width: 130, height: 180)
                VStack(spacing: 4) {
                    mediaTile(displayItems[1], width: 130, height: 88)
                    mediaTile(displayItems[2], width: 130, height: 88)
                }
            }
        default:
            LazyVGrid(
                columns: [GridItem(.fixed(130), spacing: 4), GridItem(.fixed(130), spacing: 4)],
                spacing: 4
            ) {
                ForEach(displayItems) { item in
                    mediaTile(item, width: 130, height: 130)
                }
            }
        }
    }

    private func mediaTile(_ item: ChatMediaItem, width: CGFloat, height: CGFloat) -> some View {
        Button {
            onSelect(.image(item))
        } label: {
            ChatRemoteImageView(item: item, pointSize: CGSize(width: width, height: height))
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct ChatRemoteImageView: View {
    let item: ChatMediaItem
    let pointSize: CGSize

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            MainScreenPalette.border

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView().tint(MainScreenPalette.primaryBlue)
            }
        }
        .clipped()
        .task(id: item.id) {
            await loadImage()
        }
    }

    private func loadImage() async {
        guard let request = item.thumbnailRequest else { return }

        do {
            let loaded = try await RemoteImageLoader.load(request: request, pointSize: pointSize)
            image = loaded
        } catch {
            image = nil
        }
    }
}

private struct ChatPDFRow: View {
    let item: ChatPDFItem
    let isOutgoing: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "doc.richtext.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(MainScreenPalette.primaryBlue)
                    .frame(width: 36, height: 36)
                    .background(
                        MainScreenPalette.primaryBlueSoft,
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.displayName)
                        .font(MainScreenTypography.body)
                        .foregroundStyle(isOutgoing ? .white : MainScreenPalette.textPrimary)
                        .lineLimit(1)
                    Text("PDF")
                        .font(MainScreenTypography.timestamp)
                        .foregroundStyle(
                            isOutgoing ? Color.white.opacity(0.8) : MainScreenPalette.textSecondary
                        )
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(width: 260, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isOutgoing ? MainScreenPalette.primaryBlue : MainScreenPalette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isOutgoing ? Color.clear : MainScreenPalette.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State

struct ChatStateView: View {
    let title: String
    let systemName: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(MainScreenPalette.primaryBlue)

            Text(title)
                .font(MainScreenTypography.sectionTitle)
                .foregroundStyle(MainScreenPalette.textPrimary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
