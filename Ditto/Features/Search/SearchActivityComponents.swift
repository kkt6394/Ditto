//
//  SearchActivityComponents.swift
//  Ditto
//
//  Created by Codex on 4/28/26.
//

import SwiftUI
import UIKit

struct SearchRemoteImage: View {
    let request: URLRequest?
    let fallbackImageName: String
    let width: CGFloat
    let height: CGFloat
    let cornerRadius: CGFloat

    @State private var remoteImage: UIImage?
    @State private var didFailLoadingRemoteImage = false

    var body: some View {
        fittedImage
            .frame(width: width, height: height)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var fittedImage: some View {
        if let remoteImage {
            Image(uiImage: remoteImage)
                .resizable()
                .scaledToFill()
        } else if let request, !didFailLoadingRemoteImage {
            Rectangle()
                .fill(MainScreenPalette.border)
                .overlay {
                    ProgressView()
                        .tint(MainScreenPalette.primaryBlue)
                }
                .task(id: request.url?.absoluteString) {
                    await loadRemoteImage(from: request)
                }
        } else {
            Image(fallbackImageName)
                .resizable()
                .scaledToFill()
        }
    }

    private func loadRemoteImage(from request: URLRequest) async {
        do {
            // 검색 카드 표시 크기로 다운샘플링 — 리스트 전체 메모리 부담 절감
            let image = try await RemoteImageLoader.load(
                request: request,
                pointSize: CGSize(width: width, height: height)
            )
            remoteImage = image
        } catch {
            didFailLoadingRemoteImage = true
        }
    }
}

struct LikeCircle: View {
    let isSelected: Bool

    var body: some View {
        Image(systemName: isSelected ? "heart.fill" : "heart")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isSelected ? Color(red: 1.0, green: 0.38, blue: 0.52) : .white)
            .frame(width: 24, height: 24)
            .background(Color.black.opacity(0.18), in: Circle())
    }
}

struct SearchLocationTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(MainScreenTypography.activityMetaCompact)
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(Color.white.opacity(0.16), in: Capsule())
    }
}

struct SearchStatusBanner: View {
    let status: String
    let detail: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 11, weight: .semibold))

            Text(status)
                .font(MainScreenTypography.activityMetaCompact)
                .fontWeight(.semibold)

            Text(detail)
                .font(MainScreenTypography.activityMetaCompact)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(Color.black.opacity(0.30), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.45), lineWidth: 1))
    }
}

struct SearchMetricLabel: View {
    let systemName: String
    let text: String

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: systemName)
                .font(.system(size: 10, weight: .semibold))

            Text(text)
                .font(MainScreenTypography.activityMetaCompact)
        }
        .foregroundStyle(MainScreenPalette.textSecondary)
    }
}

struct SearchStateCard: View {
    let title: String
    var subtitle: String?
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

            if let subtitle {
                Text(subtitle)
                    .font(MainScreenTypography.body)
                    .foregroundStyle(MainScreenPalette.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 140)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MainScreenPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(MainScreenPalette.border, lineWidth: 1)
        )
    }
}

// 슬라이더 영역의 위치 권한 안내 카드. CTA 버튼으로 권한 요청 또는 설정 이동을 트리거한다.
struct SearchPermissionPromptCard: View {
    let systemName: String
    let title: String
    let subtitle: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(MainScreenPalette.primaryBlue)

            Text(title)
                .font(MainScreenTypography.sectionTitle)
                .foregroundStyle(MainScreenPalette.textPrimary)
                .multilineTextAlignment(.center)

            Text(subtitle)
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: action) {
                Text(actionTitle)
                    .font(MainScreenTypography.action)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .frame(height: 36)
                    .background(MainScreenPalette.primaryBlue, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MainScreenPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(MainScreenPalette.border, lineWidth: 1)
        )
    }
}

struct SearchDistanceSliderCard: View {
    @Binding var distanceKilometers: Double
    let locationMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Text("Distance")
                    .font(MainScreenTypography.distance)
                    .foregroundStyle(MainScreenPalette.textMuted)

                Text("\(Int(distanceKilometers.rounded()))KM")
                    .font(MainScreenTypography.distance)
                    .foregroundStyle(MainScreenPalette.primaryBlue)
            }

            Slider(value: $distanceKilometers, in: 1...50, step: 1)
                .tint(MainScreenPalette.primaryBlue)

            if let locationMessage {
                Text(locationMessage)
                    .font(MainScreenTypography.timestamp)
                    .foregroundStyle(MainScreenPalette.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 12)
    }
}

struct SearchStatusTag: View {
    let text: String

    var body: some View {
        Text(text)
            .font(MainScreenTypography.activityMetaCompact)
            .foregroundStyle(MainScreenPalette.textPrimary)
            .padding(.horizontal, 8)
            .frame(height: 20)
            .background(
                MainScreenPalette.surface,
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
    }
}
