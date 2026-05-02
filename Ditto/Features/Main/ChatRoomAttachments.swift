//
//  ChatRoomAttachments.swift
//  Ditto
//
//  Created by Codex on 5/2/26.
//

import Foundation
import SwiftUI
import UIKit

// MARK: - Attachment Inputs / States

enum ChatAttachmentInput {
    case image(raw: Data)
    case pdf(filename: String, data: Data)
}

enum ChatAttachmentKind: Equatable {
    case image
    case pdf
}

enum ChatComposeAttachmentState: Equatable {
    case uploading
    case uploaded(path: String)
    case failed(message: String)
}

struct ChatComposeAttachment: Identifiable, Equatable {
    let id: UUID
    let kind: ChatAttachmentKind
    let filename: String
    let mimeType: String
    let fileData: Data
    let previewData: Data?
    var state: ChatComposeAttachmentState

    var uploadedPath: String? {
        if case .uploaded(let path) = state {
            return path
        }
        return nil
    }
}

enum ChatAttachmentError: Error {
    case oversizedAfterCompression
    case invalidImageData
    case oversizedPDF

    var userMessage: String {
        switch self {
        case .oversizedAfterCompression:
            return "사진을 5MB 이하로 줄일 수 없습니다. 더 작은 사진을 선택해 주세요."
        case .invalidImageData:
            return "사진을 읽어들이지 못했습니다."
        case .oversizedPDF:
            return "PDF는 최대 5MB까지 첨부할 수 있습니다."
        }
    }
}

// MARK: - Preparation

/// PhotosPicker / FileImporter가 넘긴 raw Data를 서버 정책에 맞춰 가공한다.
/// - 이미지: HEIC 등은 JPEG로 재인코딩, 긴 변 1600px로 다운샘플,
///   5MB 안에 들어올 때까지 quality 0.7 → 0.5 → 0.3 단계적으로 시도
/// - PDF: 5MB 초과 시 거부 (서버 한계)
enum ChatAttachmentPreparation {
    struct Prepared {
        let kind: ChatAttachmentKind
        let filename: String
        let mimeType: String
        let fileData: Data
        let previewData: Data?
    }

    static func prepare(_ input: ChatAttachmentInput) throws -> Prepared {
        switch input {
        case .image(let raw):
            return try prepareImage(rawData: raw)
        case .pdf(let filename, let data):
            return try preparePDF(filename: filename, data: data)
        }
    }

    private static func prepareImage(rawData: Data) throws -> Prepared {
        // 다운샘플로 픽셀 수 자체를 줄여 메모리·전송량을 모두 절약한다.
        let targetPoint = CGSize(width: 1600, height: 1600)
        let downsampled = RemoteImageLoader.downsample(data: rawData, pointSize: targetPoint, scale: 1)

        guard let image = downsampled ?? UIImage(data: rawData) else {
            throw ChatAttachmentError.invalidImageData
        }

        let qualities: [CGFloat] = [0.7, 0.5, 0.3]
        var compressedData: Data?
        for quality in qualities {
            guard let candidate = image.jpegData(compressionQuality: quality) else { continue }
            if candidate.count <= ChatRoomViewModel.maxAttachmentBytes {
                compressedData = candidate
                break
            }
            compressedData = candidate
        }

        guard let finalData = compressedData else {
            throw ChatAttachmentError.invalidImageData
        }

        if finalData.count > ChatRoomViewModel.maxAttachmentBytes {
            throw ChatAttachmentError.oversizedAfterCompression
        }

        // 미리보기는 작은 썸네일만 별도로 만들어 두고, 원본 finalData는 업로드용으로만 사용한다.
        let preview = image.jpegData(compressionQuality: 0.5)

        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        return Prepared(
            kind: .image,
            filename: "chat_\(timestamp).jpg",
            mimeType: "image/jpeg",
            fileData: finalData,
            previewData: preview
        )
    }

    private static func preparePDF(filename: String, data: Data) throws -> Prepared {
        if data.count > ChatRoomViewModel.maxAttachmentBytes {
            throw ChatAttachmentError.oversizedPDF
        }
        return Prepared(
            kind: .pdf,
            filename: filename,
            mimeType: "application/pdf",
            fileData: data,
            previewData: nil
        )
    }
}

// MARK: - Composer Preview Strip

struct ChatAttachmentPreviewStrip: View {
    let attachments: [ChatComposeAttachment]
    let onRemove: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { attachment in
                    ChatAttachmentPreviewTile(attachment: attachment) {
                        onRemove(attachment.id)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(MainScreenPalette.surface)
    }
}

private struct ChatAttachmentPreviewTile: View {
    let attachment: ChatComposeAttachment
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            tileBody

            statusOverlay

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .background(Circle().fill(Color.black.opacity(0.45)))
            }
            .buttonStyle(.plain)
            .padding(4)
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private var tileBody: some View {
        switch attachment.kind {
        case .image:
            if let data = attachment.previewData, let image = UIImage(data: data) {
                Color.clear
                    .overlay {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
            } else {
                placeholder(systemName: "photo")
            }
        case .pdf:
            VStack(spacing: 4) {
                Image(systemName: "doc.richtext")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(MainScreenPalette.primaryBlue)
                Text(attachment.filename)
                    .font(MainScreenTypography.timestamp)
                    .foregroundStyle(MainScreenPalette.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MainScreenPalette.primaryBlueSoft)
        }
    }

    private func placeholder(systemName: String) -> some View {
        ZStack {
            MainScreenPalette.border
            Image(systemName: systemName)
                .foregroundStyle(MainScreenPalette.textSecondary)
        }
    }

    @ViewBuilder
    private var statusOverlay: some View {
        switch attachment.state {
        case .uploading:
            ZStack {
                Color.black.opacity(0.3)
                ProgressView().tint(.white)
            }
        case .failed:
            ZStack {
                Color.black.opacity(0.55)
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.white)
            }
        case .uploaded:
            EmptyView()
        }
    }
}
