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
    // image 는 같은 메시지의 모든 사진을 한 갤러리로 묶어 좌우 스와이프가 가능하게 한다.
    case image(items: [ChatMediaItem], initialIndex: Int)
    case pdf(ChatPDFItem)

    var id: String {
        switch self {
        case .image(let items, let index):
            let itemId = items.indices.contains(index) ? items[index].id : "unknown"
            return "image-\(itemId)-\(index)"
        case .pdf(let item):
            return "pdf-" + item.id
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
    // 같은 분+같은 발신자 연속 메시지를 그룹으로 묶고, 그룹의 마지막 말풍선에만 시간을 표기한다.
    let showTime: Bool
    // 같은 발신자 연속 메시지 그룹의 첫 말풍선에만 닉네임을 표기한다 (incoming 한정).
    let showSenderName: Bool
    let onSelectMedia: (ChatMediaPresentation) -> Void
    let onTapFailed: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if isOutgoing {
                Spacer(minLength: 60)
                timeText
                outgoingColumn
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    if showSenderName {
                        Text(message.sender.nick.isEmpty ? opponentNick : message.sender.nick)
                            .font(MainScreenTypography.timestamp)
                            .foregroundStyle(MainScreenPalette.textSecondary)
                    }

                    HStack(alignment: .bottom, spacing: 6) {
                        bubbleColumn(alignment: .leading)
                        timeText
                    }
                }
                Spacer(minLength: 60)
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
            // 시간 자리에 hourglass 아이콘이 들어가므로 별도 푸터는 비운다.
            EmptyView()
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
        // .frame(maxWidth:)을 background 앞에 두면 frame이 부모 가용 폭만큼 펼쳐지고
        // 그 위에 배경이 칠해져 짧은 글자에도 말풍선이 일정 폭으로 고정된다.
        // 부모 HStack의 Spacer(minLength: 60)가 반대편 여백을 보장하므로
        // 텍스트는 가용 폭 안에서 자연스럽게 줄바꿈하고, 말풍선 너비는 글자 길이에 따라 동적으로 변한다.
        Text(message.content)
            .font(MainScreenTypography.body)
            .foregroundStyle(isOutgoing ? .white : MainScreenPalette.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bubbleColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(strokeColor, lineWidth: status == .failed ? 1.5 : 1)
            )
    }

    private var strokeColor: Color {
        if status == .failed {
            return Color(red: 0.72, green: 0.18, blue: 0.14)
        }

        return isOutgoing ? Color.clear : MainScreenPalette.border
    }

    @ViewBuilder
    private var timeText: some View {
        // sending 상태에서는 시간 자리에 모래시계 아이콘을 띄워 진행 중임을 알린다.
        // sent/failed 그룹의 마지막 메시지에만 시간을 표시하고, 같은 그룹 내부 말풍선에서는
        // 시간을 숨겨 시각적으로 묶이도록 한다.
        if status == .sending {
            Image(systemName: "hourglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(MainScreenPalette.textSecondary)
                .padding(.bottom, 2)
        } else if showTime {
            Text(formattedTime)
                .font(MainScreenTypography.timestamp)
                .foregroundStyle(MainScreenPalette.textSecondary)
                .lineLimit(1)
                .padding(.bottom, 2)
        } else {
            EmptyView()
        }
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
        let extraCount = max(items.count - displayItems.count, 0)

        switch displayItems.count {
        case 1:
            mediaTile(displayItems[0], width: 220, height: 220, index: 0, extraCount: 0)
        case 2:
            HStack(spacing: 4) {
                mediaTile(displayItems[0], width: 130, height: 180, index: 0, extraCount: 0)
                mediaTile(displayItems[1], width: 130, height: 180, index: 1, extraCount: 0)
            }
        case 3:
            HStack(spacing: 4) {
                mediaTile(displayItems[0], width: 130, height: 180, index: 0, extraCount: 0)
                VStack(spacing: 4) {
                    mediaTile(displayItems[1], width: 130, height: 88, index: 1, extraCount: 0)
                    mediaTile(displayItems[2], width: 130, height: 88, index: 2, extraCount: 0)
                }
            }
        default:
            // maxAttachmentCount = 5 이므로 displayItems 는 최대 4장.
            // 5장째가 있으면 마지막 가시 타일에 "+1" 오버레이로 가려진 사진을 알린다.
            LazyVGrid(
                columns: [GridItem(.fixed(130), spacing: 4), GridItem(.fixed(130), spacing: 4)],
                spacing: 4
            ) {
                ForEach(Array(displayItems.enumerated()), id: \.element.id) { index, item in
                    let overlay = index == displayItems.count - 1 ? extraCount : 0
                    mediaTile(item, width: 130, height: 130, index: index, extraCount: overlay)
                }
            }
        }
    }

    private func mediaTile(
        _ item: ChatMediaItem,
        width: CGFloat,
        height: CGFloat,
        index: Int,
        extraCount: Int
    ) -> some View {
        Button {
            // 갤러리 진입 시 메시지의 전체 사진 + 누른 사진의 인덱스를 함께 전달해
            // 풀스크린에서 좌우 스와이프로 다른 사진을 볼 수 있게 한다.
            onSelect(.image(items: items, initialIndex: index))
        } label: {
            ChatRemoteImageView(item: item, pointSize: CGSize(width: width, height: height))
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    if extraCount > 0 {
                        ZStack {
                            Color.black.opacity(0.5)
                            Text("+\(extraCount)")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
        }
        .buttonStyle(.plain)
    }
}

private struct ChatRemoteImageView: View {
    let item: ChatMediaItem
    let pointSize: CGSize

    @Environment(\.imageLoader) private var imageLoader
    @State private var image: UIImage?
    @State private var loadFailed = false

    var body: some View {
        ZStack {
            MainScreenPalette.border

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if loadFailed {
                // 네트워크/권한 등으로 이미지를 못 받았을 때 영구 스피너 대신 명확한 실패 표시.
                VStack(spacing: 4) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 20, weight: .semibold))
                    Text("불러오기 실패")
                        .font(MainScreenTypography.timestamp)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(MainScreenPalette.textSecondary)
                .padding(8)
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
        guard let request = item.thumbnailRequest else {
            loadFailed = true
            return
        }

        do {
            // 환경에 인증 로더가 주입되어 있으면 토큰 만료(419) 자동 갱신 흐름을 탄다.
            let loaded: UIImage
            if let imageLoader {
                loaded = try await imageLoader.loadImage(request, pointSize: pointSize)
            } else {
                loaded = try await RemoteImageLoader.load(request: request, pointSize: pointSize)
            }
            image = loaded
            loadFailed = false
        } catch {
            image = nil
            loadFailed = true
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
                        // 긴 파일명은 가운데를 생략해 확장자(.pdf)는 보존한다.
                        .truncationMode(.middle)
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
            // 작은 화면(예: iPhone SE)에선 부모 폭에 맞춰 줄어들고, 넓은 화면에선 260pt 까지만 차지.
            .frame(maxWidth: 260, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isOutgoing ? MainScreenPalette.primaryBlue : MainScreenPalette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
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
