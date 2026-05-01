//
//  ProfileTabComponents.swift
//  Ditto
//
//  Created by Codex on 5/1/26.
//

import SwiftUI

// MARK: - Header card

struct ProfileHeaderCard: View {
    let profile: ProfileSummary
    let imageRequest: URLRequest?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                ProfileAvatar(imageRequest: imageRequest, size: 72)

                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.nick)
                        .font(MainFont.pretendard(.bold, size: 18))
                        .foregroundStyle(MainScreenPalette.textPrimary)
                        .lineLimit(1)

                    Text(profile.email)
                        .font(MainScreenTypography.body)
                        .foregroundStyle(MainScreenPalette.textSecondary)
                        .lineLimit(1)
                }

                Spacer()
            }

            Divider()
                .overlay(MainScreenPalette.border)

            Text(profile.displayIntroduction)
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            ProfileMetaRow(label: "전화번호", value: profile.displayPhoneNumber)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MainScreenPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MainScreenPalette.border, lineWidth: 1)
        )
    }
}

struct ProfileAvatar: View {
    let imageRequest: URLRequest?
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(MainScreenPalette.primaryBlueSoft)

            if let imageRequest {
                SearchRemoteImage(
                    request: imageRequest,
                    fallbackImageName: "FigmaMainNewActivity1",
                    width: size,
                    height: size,
                    cornerRadius: size / 2
                )
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(MainScreenPalette.primaryBlue)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(MainScreenPalette.borderBlue, lineWidth: 1)
        )
    }
}

struct ProfileMetaRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .font(MainFont.pretendard(.semibold, size: 13))
                .foregroundStyle(MainScreenPalette.textSecondary)
                .frame(width: 64, alignment: .leading)

            Text(value)
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Skeleton / error / banner

struct ProfileCardSkeleton: View {
    var body: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(MainScreenPalette.border)
                .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(MainScreenPalette.border)
                    .frame(width: 140, height: 16)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(MainScreenPalette.border)
                    .frame(width: 180, height: 12)
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MainScreenPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MainScreenPalette.border, lineWidth: 1)
        )
    }
}

struct ProfileErrorCard: View {
    let message: String
    let retryAction: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(MainScreenPalette.textMuted)

            Text(message)
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: retryAction) {
                Text("다시 시도")
                    .font(MainFont.pretendard(.bold, size: 13))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(MainScreenPalette.primaryBlue, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(MainScreenPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MainScreenPalette.border, lineWidth: 1)
        )
    }
}

struct ProfileMessageBanner: View {
    let message: String

    var body: some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(MainFont.pretendard(.semibold, size: 13))
            .foregroundStyle(Color(red: 0.72, green: 0.18, blue: 0.14))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                Color(red: 0.72, green: 0.18, blue: 0.14).opacity(0.10),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
    }
}

// MARK: - Stats / actions

struct ProfileStatTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(MainFont.pretendard(.semibold, size: 12))
                .foregroundStyle(MainScreenPalette.textSecondary)
            Text(value)
                .font(MainFont.pretendard(.bold, size: 22))
                .foregroundStyle(MainScreenPalette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MainScreenPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MainScreenPalette.border, lineWidth: 1)
        )
    }
}

struct ProfileActionRow: View {
    enum Style {
        case primary
        case secondary
        case destructive
    }

    let title: String
    let systemImage: String
    let style: Style

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
            Text(title)
                .font(MainFont.pretendard(.bold, size: 15))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .opacity(0.6)
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(background)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var foreground: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return MainScreenPalette.textPrimary
        case .destructive:
            return Color(red: 0.72, green: 0.18, blue: 0.14)
        }
    }

    private var background: some View {
        Group {
            switch style {
            case .primary:
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(MainScreenPalette.primaryBlue)
            case .secondary:
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(MainScreenPalette.surface)
            case .destructive:
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(red: 0.72, green: 0.18, blue: 0.14).opacity(0.08))
            }
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary:
            return MainScreenPalette.primaryBlue
        case .secondary:
            return MainScreenPalette.border
        case .destructive:
            return Color(red: 0.72, green: 0.18, blue: 0.14).opacity(0.3)
        }
    }
}

// MARK: - Section

struct ProfileSectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(MainFont.pretendard(.bold, size: 16))
            .foregroundStyle(MainScreenPalette.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ProfileSectionLoading: View {
    var body: some View {
        HStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .frame(height: 80)
    }
}

struct ProfileSectionEmpty: View {
    let message: String

    var body: some View {
        Text(message)
            .font(MainScreenTypography.body)
            .foregroundStyle(MainScreenPalette.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
    }
}

struct ProfilePostHorizontalList: View {
    let items: [ProfilePostPreview]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(items) { item in
                    ProfilePostCard(item: item)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct ProfilePostCard: View {
    let item: ProfilePostPreview

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SearchRemoteImage(
                request: item.imageRequest,
                fallbackImageName: "FigmaMainNewActivity1",
                width: 160,
                height: 110,
                cornerRadius: 12
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(MainFont.pretendard(.bold, size: 13))
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .lineLimit(1)

                Text(item.location)
                    .font(MainScreenTypography.activityMetaCompact)
                    .foregroundStyle(MainScreenPalette.textSecondary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(MainScreenPalette.primaryBlue)
                    Text("\(item.likeCount)")
                        .font(MainFont.pretendard(.semibold, size: 11))
                        .foregroundStyle(MainScreenPalette.primaryBlue)
                }
            }
            .frame(width: 160, alignment: .leading)
        }
    }
}
