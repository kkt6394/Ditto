//
//  ActivityDetailReviewComponents.swift
//  Ditto
//
//  Created by Codex on 4/29/26.
//

import SwiftUI
import UIKit

struct ReviewSection: View {
    let reviews: [ReviewResponseDTO]
    let isLoading: Bool
    let message: String?
    let currentUserId: String?
    let chatStartMessage: String?
    let sentimentSummary: ReviewSentimentSummary?
    let aiSummary: ReviewSummary?
    let isAnalyzing: Bool
    let imageRequestProvider: (String) -> URLRequest?
    let chatAction: (ReviewResponseDTO) -> Void
    let editAction: (ReviewResponseDTO) -> Void
    let deleteAction: (ReviewResponseDTO) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("리뷰")
                    .font(MainScreenTypography.sectionTitle)
                    .foregroundStyle(MainScreenPalette.textPrimary)

                Text("\(reviews.count)")
                    .font(MainScreenTypography.timestamp)
                    .foregroundStyle(MainScreenPalette.textSecondary)
            }

            if !reviews.isEmpty {
                ReviewInsightCard(
                    sentimentSummary: sentimentSummary,
                    aiSummary: aiSummary,
                    isAnalyzing: isAnalyzing
                )
            }

            if isLoading && reviews.isEmpty {
                ReviewStateCard(title: "리뷰를 불러오는 중입니다.", systemName: "arrow.clockwise")
            } else if reviews.isEmpty {
                ReviewStateCard(
                    title: message ?? "아직 작성된 리뷰가 없습니다.",
                    systemName: "text.bubble"
                )
            } else {
                VStack(spacing: 10) {
                    ForEach(reviews, id: \.reviewId) { review in
                        ReviewCard(
                            review: review,
                            isMine: currentUserId == review.creator.userId,
                            imageRequestProvider: imageRequestProvider,
                            chatAction: chatAction,
                            editAction: editAction,
                            deleteAction: deleteAction
                        )
                    }
                }
            }

            if let chatStartMessage {
                Text(chatStartMessage)
                    .font(MainScreenTypography.timestamp)
                    .foregroundStyle(Color(red: 0.72, green: 0.18, blue: 0.14))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ReviewCard: View {
    let review: ReviewResponseDTO
    let isMine: Bool
    let imageRequestProvider: (String) -> URLRequest?
    let chatAction: (ReviewResponseDTO) -> Void
    let editAction: (ReviewResponseDTO) -> Void
    let deleteAction: (ReviewResponseDTO) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                ReviewProfileImage(
                    request: review.creator.profileImage.flatMap(imageRequestProvider)
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(review.creator.nick)
                        .font(MainFont.pretendard(.bold, size: 14))
                        .foregroundStyle(MainScreenPalette.textPrimary)
                        .lineLimit(1)

                    ReviewRatingStars(rating: review.rating)
                }

                Spacer()

                if isMine {
                    Menu {
                        Button("수정") { editAction(review) }
                        Button("삭제", role: .destructive) { deleteAction(review) }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(MainScreenPalette.textSecondary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("내 리뷰 메뉴")
                } else {
                    Button {
                        chatAction(review)
                    } label: {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(MainScreenPalette.primaryBlue, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(review.creator.nick)님과 채팅하기")
                }
            }

            Text(review.content)
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)

            if !review.reviewImageUrls.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(review.reviewImageUrls, id: \.self) { path in
                            ReviewImageThumbnail(request: imageRequestProvider(path))
                        }
                    }
                }
            }
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

private struct ReviewRatingStars: View {
    let rating: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: index < rating ? "star.fill" : "star")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(MainScreenPalette.primaryBlue)
            }
        }
    }
}

private struct ReviewProfileImage: View {
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
        .frame(width: 36, height: 36)
        .clipShape(Circle())
    }

    private func load(_ request: URLRequest) async {
        do {
            // 36×36 프로필 표시 크기로 다운샘플링
            let pointSize = CGSize(width: 36, height: 36)
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

private struct ReviewImageThumbnail: View {
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
                Image(systemName: "photo")
                    .font(.system(size: 16))
                    .foregroundStyle(MainScreenPalette.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(MainScreenPalette.border)
            }
        }
        .frame(width: 88, height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func load(_ request: URLRequest) async {
        do {
            // 88×88 썸네일 표시 크기로 다운샘플링
            let pointSize = CGSize(width: 88, height: 88)
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

// 리뷰 묶음에 대한 AI 요약 + 감성 분포를 보여주는 상단 인사이트 카드.
private struct ReviewInsightCard: View {
    let sentimentSummary: ReviewSentimentSummary?
    let aiSummary: ReviewSummary?
    let isAnalyzing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MainScreenPalette.primaryBlue)

                Text("AI 리뷰 요약")
                    .font(MainFont.pretendard(.bold, size: 13))
                    .foregroundStyle(MainScreenPalette.textPrimary)

                if let aiSummary, let chipLabel = Self.modeChipLabel(for: aiSummary.source) {
                    Text(chipLabel)
                        .font(MainScreenTypography.timestamp)
                        .foregroundStyle(MainScreenPalette.textSecondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(MainScreenPalette.border, in: Capsule())
                }

                Spacer()
            }

            Group {
                if let aiSummary {
                    Text(aiSummary.text)
                        .font(MainScreenTypography.body)
                        .foregroundStyle(MainScreenPalette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if isAnalyzing {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("리뷰를 요약하는 중입니다…")
                            .font(MainScreenTypography.body)
                            .foregroundStyle(MainScreenPalette.textSecondary)
                    }
                } else {
                    Text("요약을 준비 중입니다.")
                        .font(MainScreenTypography.body)
                        .foregroundStyle(MainScreenPalette.textSecondary)
                }
            }

            if let sentimentSummary, sentimentSummary.total > 0 {
                ReviewSentimentBar(summary: sentimentSummary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MainScreenPalette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(MainScreenPalette.border, lineWidth: 1)
        )
    }

    // 어느 fallback 단계에서 만들어졌는지 사용자에게 살짝 노출하기 위한 라벨.
    // LLM 응답일 땐 칩을 안 띄워서 일반 모드처럼 보이게 한다.
    private static func modeChipLabel(for source: ReviewSummary.Source) -> String? {
        switch source {
        case .foundationModels: return nil
        case .statsTemplate: return "통계 모드"
        }
    }
}

// 긍정/중립/부정 비율을 한 줄 막대로 보여준다.
private struct ReviewSentimentBar: View {
    let summary: ReviewSentimentSummary

    private let positiveColor = Color(red: 0.20, green: 0.62, blue: 0.36)
    private let neutralColor = Color(red: 0.66, green: 0.66, blue: 0.66)
    private let negativeColor = Color(red: 0.78, green: 0.24, blue: 0.20)

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { proxy in
                let total = max(summary.total, 1)
                let positiveWidth = proxy.size.width * Double(summary.positive) / Double(total)
                let neutralWidth = proxy.size.width * Double(summary.neutral) / Double(total)
                let negativeWidth = proxy.size.width * Double(summary.negative) / Double(total)

                HStack(spacing: 0) {
                    Rectangle().fill(positiveColor).frame(width: positiveWidth)
                    Rectangle().fill(neutralColor).frame(width: neutralWidth)
                    Rectangle().fill(negativeColor).frame(width: negativeWidth)
                }
                .clipShape(Capsule())
            }
            .frame(height: 6)

            HStack(spacing: 12) {
                sentimentLegend(color: positiveColor, label: "긍정", count: summary.positive)
                sentimentLegend(color: neutralColor, label: "중립", count: summary.neutral)
                sentimentLegend(color: negativeColor, label: "부정", count: summary.negative)
                Spacer()
            }
        }
    }

    private func sentimentLegend(color: Color, label: String, count: Int) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text("\(label) \(count)")
                .font(MainScreenTypography.timestamp)
                .foregroundStyle(MainScreenPalette.textSecondary)
        }
    }
}

private struct ReviewStateCard: View {
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
