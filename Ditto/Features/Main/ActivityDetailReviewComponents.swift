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
    let imageRequestProvider: (String) -> URLRequest?
    let chatAction: (ReviewResponseDTO) -> Void

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
                            chatAction: chatAction
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

                if !isMine {
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
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let loaded = UIImage(data: data) else {
                didFail = true
                return
            }

            image = loaded
        } catch {
            didFail = true
        }
    }
}

private struct ReviewImageThumbnail: View {
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
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let loaded = UIImage(data: data) else {
                didFail = true
                return
            }

            image = loaded
        } catch {
            didFail = true
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
