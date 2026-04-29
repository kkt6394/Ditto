//
//  PostComposeComponents.swift
//  Ditto
//
//  Created by Codex on 4/29/26.
//

import PhotosUI
import SwiftUI

enum PostComposePalette {
    static let primaryText = MainScreenPalette.textPrimary
    static let secondaryText = MainScreenPalette.textSecondary
    static let inputBackground = MainScreenPalette.surface
    static let inputBorder = MainScreenPalette.border
    static let accent = MainScreenPalette.primaryBlue
    static let accentSoft = MainScreenPalette.primaryBlueSoft
    static let danger = Color(red: 0.85, green: 0.27, blue: 0.27)
    static let placeholder = MainScreenPalette.textMuted
}

struct PostComposeNavigationBar: View {
    let canSubmit: Bool
    let isSubmitting: Bool
    let cancelAction: () -> Void
    let submitAction: () -> Void

    var body: some View {
        HStack {
            Button(action: cancelAction) {
                Text("닫기")
                    .font(MainScreenTypography.action)
                    .foregroundStyle(PostComposePalette.secondaryText)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("새 글쓰기")
                .font(MainScreenTypography.sectionTitle)
                .foregroundStyle(PostComposePalette.primaryText)

            Spacer()

            Button(action: submitAction) {
                if isSubmitting {
                    ProgressView()
                        .tint(PostComposePalette.accent)
                } else {
                    Text("게시")
                        .font(MainScreenTypography.action)
                        .foregroundStyle(canSubmit ? PostComposePalette.accent : PostComposePalette.placeholder)
                }
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit)
        }
        .frame(height: 52)
        .padding(.horizontal, 20)
        .background(MainScreenPalette.surface)
        .overlay(alignment: .bottom) {
            Divider().overlay(MainScreenPalette.border)
        }
    }
}

struct PostComposeFieldLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(MainScreenTypography.sectionTitle)
            .foregroundStyle(PostComposePalette.primaryText)
    }
}

struct PostComposeChipPicker: View {
    let title: String
    let options: [String]
    @Binding var selection: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PostComposeFieldLabel(title: title)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(options, id: \.self) { option in
                        let isSelected = option == selection

                        Button {
                            selection = option
                        } label: {
                            Text(option)
                                .font(MainScreenTypography.category)
                                .foregroundStyle(
                                    isSelected
                                        ? PostComposePalette.accent
                                        : PostComposePalette.secondaryText
                                )
                                .padding(.horizontal, 14)
                                .frame(height: 32)
                                .background(
                                    Capsule().fill(
                                        isSelected
                                            ? PostComposePalette.accentSoft
                                            : PostComposePalette.inputBackground
                                    )
                                )
                                .overlay(
                                    Capsule().stroke(
                                        isSelected ? MainScreenPalette.borderBlue : PostComposePalette.inputBorder,
                                        lineWidth: 1
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct PostComposeTitleField: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PostComposeFieldLabel(title: "제목")

            TextField("", text: $text, prompt: Text("제목을 입력하세요").foregroundColor(PostComposePalette.placeholder))
                .font(MainScreenTypography.postTitle)
                .foregroundStyle(PostComposePalette.primaryText)
                .padding(.horizontal, 14)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(PostComposePalette.inputBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(PostComposePalette.inputBorder, lineWidth: 1)
                )
        }
    }
}

struct PostComposeContentField: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PostComposeFieldLabel(title: "내용")

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("이번 액티비티는 어땠는지 자유롭게 적어보세요.")
                        .font(MainScreenTypography.body)
                        .foregroundStyle(PostComposePalette.placeholder)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }

                TextEditor(text: $text)
                    .font(MainScreenTypography.body)
                    .foregroundStyle(PostComposePalette.primaryText)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .frame(minHeight: 140, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(PostComposePalette.inputBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(PostComposePalette.inputBorder, lineWidth: 1)
            )
        }
    }
}

struct PostComposeActivityRow: View {
    let activity: PostComposeActivityCandidate?
    let pickAction: () -> Void
    let clearAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PostComposeFieldLabel(title: "연결할 액티비티 (필수)")

            Button(action: pickAction) {
                HStack(spacing: 12) {
                    Image(systemName: "link.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(PostComposePalette.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(activity?.title ?? "액티비티를 선택하세요")
                            .font(MainScreenTypography.postTitle)
                            .foregroundStyle(
                                activity == nil
                                    ? PostComposePalette.placeholder
                                    : PostComposePalette.primaryText
                            )
                            .lineLimit(1)

                        if let activity {
                            Text(metaText(for: activity))
                                .font(MainScreenTypography.bodyCompact)
                                .foregroundStyle(PostComposePalette.secondaryText)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    if activity != nil {
                        Button(action: clearAction) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(PostComposePalette.placeholder)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(PostComposePalette.placeholder)
                    }
                }
                .padding(.horizontal, 14)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(PostComposePalette.inputBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(PostComposePalette.inputBorder, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func metaText(for activity: PostComposeActivityCandidate) -> String {
        [activity.country, activity.category]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}

struct PostComposeAttachmentGrid: View {
    let attachments: [PostComposeAttachment]
    let pickerSelection: Binding<[PhotosPickerItem]>
    let removeAction: (UUID) -> Void
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 0)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PostComposeFieldLabel(title: "사진 (최대 3장)")

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(attachments) { attachment in
                    AttachmentThumbnail(attachment: attachment) {
                        removeAction(attachment.id)
                    }
                }

                if attachments.count < 3 {
                    PhotosPicker(
                        selection: pickerSelection,
                        maxSelectionCount: 3 - attachments.count,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        AddPhotoTile()
                    }
                }
            }
        }
    }
}

private struct AttachmentThumbnail: View {
    let attachment: PostComposeAttachment
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
            // Color.clear가 부모 셀(정사각형) 크기를 받고, overlay 안의 Image가 그 크기에 맞춰 fill 된다.
            // GeometryReader 패턴보다 SwiftUI 레이아웃 사이클에 안전하게 동작한다.
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

private struct AddPhotoTile: View {
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
                .stroke(MainScreenPalette.borderBlue, lineWidth: 1)
        )
    }
}

struct PostComposeLocationToggle: View {
    @Binding var useCurrentLocation: Bool
    let coordinate: UserCoordinate?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(PostComposePalette.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("현재 위치 사용")
                    .font(MainScreenTypography.postTitle)
                    .foregroundStyle(PostComposePalette.primaryText)

                Text(coordinate == nil ? "위치 권한이 없거나 좌표를 가져올 수 없습니다." : coordinateText)
                    .font(MainScreenTypography.bodyCompact)
                    .foregroundStyle(PostComposePalette.secondaryText)
            }

            Spacer()

            Toggle("", isOn: $useCurrentLocation)
                .labelsHidden()
                .tint(PostComposePalette.accent)
                .disabled(coordinate == nil)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 56)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(PostComposePalette.inputBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(PostComposePalette.inputBorder, lineWidth: 1)
        )
    }

    private var coordinateText: String {
        guard let coordinate else { return "" }
        let lat = String(format: "%.4f", coordinate.latitude)
        let lng = String(format: "%.4f", coordinate.longitude)
        return "위도 \(lat) · 경도 \(lng)"
    }
}

struct PostComposeMessageBanner: View {
    let message: String

    var body: some View {
        Text(message)
            .font(MainScreenTypography.body)
            .foregroundStyle(PostComposePalette.danger)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(red: 1.0, green: 0.94, blue: 0.94))
            )
    }
}

struct PostComposeFloatingButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle().fill(MainScreenPalette.primaryBlue)
                )
                .shadow(color: MainScreenPalette.shadow, radius: 6, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("액티비티 포스트 글쓰기")
    }
}
