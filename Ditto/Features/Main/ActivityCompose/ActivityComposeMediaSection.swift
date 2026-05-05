//
//  ActivityComposeMediaSection.swift
//  Ditto
//
//  Created by Codex on 5/5/26.
//

import PhotosUI
import SwiftUI

// 사진 첨부 섹션. PostCompose의 그리드와 거의 동일한 구조이지만 attachment 타입이 달라
// 별도 컴포넌트로 둔다(PostCompose 측 코드는 건드리지 않는다).
struct ActivityComposeMediaSection: View {
    let attachments: [ActivityComposeAttachment]
    let existingThumbnails: [ActivityComposeExistingThumbnail]
    @Binding var pickerSelection: [PhotosPickerItem]
    let availableSlotCount: Int
    let removeAction: (UUID) -> Void
    let toggleExistingDeletion: (UUID) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 0)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PostComposeFieldLabel(title: "사진 (최대 5장)")

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(attachments) { attachment in
                    ActivityAttachmentThumbnail(attachment: attachment) {
                        removeAction(attachment.id)
                    }
                }

                if availableSlotCount > 0 {
                    PhotosPicker(
                        selection: $pickerSelection,
                        maxSelectionCount: availableSlotCount,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        ActivityAddPhotoTile()
                    }
                }
            }

            if !existingThumbnails.isEmpty {
                existingThumbnailsList
            }
        }
    }

    // 편집 모드: 서버가 보유한 사진 path를 행 단위로 표시한다.
    // 인증 헤더 포함 AsyncImage 처리는 후속 개선 — 이번 단계는 path 마지막 segment + 삭제 토글.
    private var existingThumbnailsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("기존 사진")
                .font(MainScreenTypography.bodyCompact)
                .foregroundStyle(MainScreenPalette.textSecondary)

            VStack(spacing: 6) {
                ForEach(existingThumbnails) { thumbnail in
                    ExistingThumbnailRow(thumbnail: thumbnail) {
                        toggleExistingDeletion(thumbnail.id)
                    }
                }
            }
        }
    }
}

private struct ExistingThumbnailRow: View {
    let thumbnail: ActivityComposeExistingThumbnail
    let toggleAction: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "photo")
                .font(.system(size: 16))
                .foregroundStyle(MainScreenPalette.textSecondary)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(PostComposePalette.inputBackground)
                )

            Text(thumbnail.path.split(separator: "/").last.map(String.init) ?? thumbnail.path)
                .font(MainScreenTypography.bodyCompact)
                .foregroundStyle(
                    thumbnail.isMarkedForDeletion
                        ? MainScreenPalette.textMuted
                        : MainScreenPalette.textPrimary
                )
                .strikethrough(thumbnail.isMarkedForDeletion)
                .lineLimit(1)

            Spacer()

            Button(action: toggleAction) {
                Image(
                    systemName: thumbnail.isMarkedForDeletion
                        ? "arrow.uturn.backward.circle"
                        : "trash.circle"
                )
                .font(.system(size: 22))
                .foregroundStyle(
                    thumbnail.isMarkedForDeletion ? MainScreenPalette.primaryBlue : .red
                )
            }
            .buttonStyle(.plain)
        }
    }
}

private struct ActivityAttachmentThumbnail: View {
    let attachment: ActivityComposeAttachment
    let removeAction: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            thumbnailLayer

            statusOverlay

            Button(action: removeAction) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .background(Circle().fill(Color.black.opacity(0.45)))
            }
            .buttonStyle(.plain)
            .padding(6)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private var thumbnailLayer: some View {
        if let image = UIImage(data: attachment.previewData) {
            // 부모 셀(정사각형)이 크기를 잡고, overlay 안의 Image가 그 크기에 맞춰 fill 된다.
            Color.clear
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
        } else {
            Rectangle()
                .fill(MainScreenPalette.border)
        }
    }

    @ViewBuilder
    private var statusOverlay: some View {
        switch attachment.state {
        case .uploading:
            ZStack {
                Color.black.opacity(0.25)
                ProgressView().tint(.white)
            }
        case .failed:
            ZStack {
                Color.black.opacity(0.5)
                VStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.white)
                    Text("실패")
                        .font(MainScreenTypography.bodyCompact)
                        .foregroundStyle(.white)
                }
            }
        case .uploaded:
            EmptyView()
        }
    }
}

private struct ActivityAddPhotoTile: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(PostComposePalette.accent)

            Text("사진 추가")
                .font(MainScreenTypography.bodyCompact)
                .foregroundStyle(PostComposePalette.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(PostComposePalette.accentSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(PostComposePalette.inputBorder, lineWidth: 1)
        )
    }
}
