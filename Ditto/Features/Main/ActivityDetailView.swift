//
//  ActivityDetailView.swift
//  Ditto
//
//  Created by Codex on 4/28/26.
//

import Observation
import SwiftUI
import UIKit

struct ActivityDetailView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: ActivityDetailViewModel

    init(activityId: String, authManager: any AuthManaging) {
        _viewModel = State(initialValue: ActivityDetailViewModel(activityId: activityId, authManager: authManager))
    }

    var body: some View {
        VStack(spacing: 0) {
            navigationBar

            if viewModel.isLoading && viewModel.activity == nil {
                ActivityDetailStateView(title: "액티비티 상세 정보를 불러오는 중입니다.", systemName: "arrow.clockwise")
                    .frame(maxHeight: .infinity)
            } else if let activity = viewModel.activity {
                detailContent(activity)
            } else {
                ActivityDetailStateView(
                    title: viewModel.message ?? "액티비티 정보를 확인할 수 없습니다.",
                    systemName: "exclamationmark.circle"
                )
                .frame(maxHeight: .infinity)
            }
        }
        .background(MainScreenPalette.background.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: viewModel.activityId) {
            await viewModel.loadDetail()
        }
    }

    private var navigationBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("액티비티")
                .font(MainScreenTypography.brand)
                .foregroundStyle(MainScreenPalette.primaryBlue)

            Spacer()

            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 4)
        .frame(height: 44)
        .background(MainScreenPalette.background)
    }

    private func detailContent(_ activity: ActivityResponseDTO) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                ActivityDetailRemoteImage(
                    request: viewModel.heroImageRequest,
                    fallbackImageName: "FigmaMainNewActivity2"
                )

                VStack(alignment: .leading, spacing: 14) {
                    Text(activity.title ?? "제목 없는 액티비티")
                        .font(MainFont.paperlogyBlack(size: 26))
                        .foregroundStyle(MainScreenPalette.textPrimary)

                    Text(activity.description ?? "상세 설명이 없습니다.")
                        .font(MainScreenTypography.postBody)
                        .foregroundStyle(MainScreenPalette.textSecondary)
                        .lineSpacing(5)

                    HStack(spacing: 10) {
                        PostInfoBadge(text: activity.country ?? "위치 정보 없음", systemName: "location.fill")
                        PostInfoBadge(text: activity.category ?? "액티비티", systemName: "tag.fill")
                    }
                }
                .padding(.horizontal, 20)

                ActivityPricePanel(
                    originalPrice: viewModel.priceText(activity.price.original),
                    finalPrice: viewModel.priceText(activity.price.final),
                    discountRate: viewModel.discountRateText(
                        originalPrice: activity.price.original,
                        finalPrice: activity.price.final
                    )
                )
                .padding(.horizontal, 20)

                ActivityLimitPanel(activity: activity)
                    .padding(.horizontal, 20)

                if let schedule = activity.schedule, !schedule.isEmpty {
                    ActivitySchedulePanel(schedule: schedule)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, SearchLayout.tabBarContentPadding)
        }
    }
}

@MainActor
@Observable
final class ActivityDetailViewModel {
    let activityId: String
    private(set) var activity: ActivityResponseDTO?
    private(set) var heroImageRequest: URLRequest?
    private(set) var isLoading = false
    private(set) var message: String?

    private let authManager: any AuthManaging

    init(activityId: String, authManager: any AuthManaging) {
        self.activityId = activityId
        self.authManager = authManager
    }

    func loadDetail() async {
        isLoading = true
        message = nil
        defer {
            isLoading = false
        }

        do {
            let configuration = try AppConfiguration()
            let networkManager = NetworkManager(configuration: configuration, authManager: authManager)
            let response: ActivityResponseDTO = try await networkManager.request(
                ActivityRouter.detail(activityId: activityId)
            )
            activity = response
            heroImageRequest = makeImageRequest(
                from: response.thumbnails.first(where: Self.isImagePath),
                configuration: configuration
            )
        } catch {
            message = Self.makeErrorMessage(from: error)
        }
    }

    func priceText(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        let numberText = formatter.string(from: NSNumber(value: price)) ?? "\(Int(price))"
        return "\(numberText)원"
    }

    func discountRateText(originalPrice: Double, finalPrice: Double) -> String? {
        guard originalPrice > finalPrice, originalPrice > 0 else {
            return nil
        }

        let discount = ((originalPrice - finalPrice) / originalPrice * 100).rounded()
        return "\(Int(discount))%"
    }

    private func makeImageRequest(from path: String?, configuration: AppConfiguration) -> URLRequest? {
        guard let path, !path.isEmpty, let url = makeURL(from: path, baseURL: configuration.baseURL) else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue(configuration.apiKey, forHTTPHeaderField: "SeSACKey")

        if let accessToken = authManager.tokens?.accessToken {
            request.setValue(accessToken, forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func makeURL(from path: String, baseURL: URL) -> URL? {
        if let url = URL(string: path), url.scheme != nil {
            return url
        }

        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var imagePath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if imagePath.hasPrefix("data/") {
            imagePath = "v1/" + imagePath
        }

        components.path = "/" + [basePath, imagePath]
            .filter { !$0.isEmpty }
            .joined(separator: "/")

        return components.url
    }

    private static func isImagePath(_ path: String) -> Bool {
        let lowercasedPath = path.lowercased()

        return [".jpg", ".jpeg", ".png", ".webp"].contains { imageExtension in
            lowercasedPath.hasSuffix(imageExtension)
        }
    }

    private static func makeErrorMessage(from error: Error) -> String {
        switch error {
        case let error as NetworkError:
            switch error {
            case .missingAuthenticationToken:
                return "로그인이 필요합니다."
            case .statusCode(_, let message, _):
                return message ?? "액티비티 정보를 불러오지 못했습니다."
            case .requestFailed:
                return "네트워크 연결을 확인해 주세요."
            default:
                return "액티비티 정보를 불러오지 못했습니다."
            }
        case AppConfigurationError.missingValue, AppConfigurationError.invalidURL:
            return "API 설정값을 확인해 주세요."
        default:
            return "액티비티 정보를 불러오지 못했습니다."
        }
    }
}

private struct ActivityDetailRemoteImage: View {
    let request: URLRequest?
    let fallbackImageName: String

    @State private var remoteImage: UIImage?
    @State private var didFailLoadingRemoteImage = false

    var body: some View {
        fittedImage
            .frame(maxWidth: .infinity)
            .frame(height: 360)
            .clipped()
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
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  let image = UIImage(data: data) else {
                didFailLoadingRemoteImage = true
                return
            }

            remoteImage = image
        } catch {
            didFailLoadingRemoteImage = true
        }
    }
}

private struct ActivityPricePanel: View {
    let originalPrice: String
    let finalPrice: String
    let discountRate: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(originalPrice)
                .font(MainFont.paperlogyBlack(size: 14))
                .foregroundStyle(MainScreenPalette.textMuted)
                .strikethrough()

            HStack(spacing: 8) {
                Text("판매가")
                Text(finalPrice)
                if let discountRate {
                    Text(discountRate)
                        .foregroundStyle(MainScreenPalette.primaryBlue)
                }
            }
            .font(MainFont.paperlogyBlack(size: 22))
            .foregroundStyle(MainScreenPalette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(MainScreenPalette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MainScreenPalette.border, lineWidth: 1)
        )
    }
}

private struct ActivityLimitPanel: View {
    let activity: ActivityResponseDTO

    var body: some View {
        HStack(spacing: 8) {
            ActivityLimitItem(title: "최소 키", value: "\(Int(activity.restrictions.minHeight))cm")
            ActivityLimitItem(title: "최소 나이", value: "\(Int(activity.restrictions.minAge))세")
            ActivityLimitItem(title: "최대 인원", value: "\(Int(activity.restrictions.maxParticipants))명")
        }
        .padding(16)
        .background(MainScreenPalette.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MainScreenPalette.border, lineWidth: 1)
        )
    }
}

private struct ActivityLimitItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(MainScreenTypography.timestamp)
                .foregroundStyle(MainScreenPalette.textSecondary)

            Text(value)
                .font(MainFont.pretendard(.bold, size: 14))
                .foregroundStyle(MainScreenPalette.textPrimary)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ActivitySchedulePanel: View {
    let schedule: [ActivityScheduleItemDTO]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("액티비티 커리큘럼")
                .font(MainScreenTypography.sectionTitle)
                .foregroundStyle(MainScreenPalette.textPrimary)

            ForEach(Array(schedule.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.duration ?? "진행 시간")
                        .font(MainFont.pretendard(.bold, size: 14))
                        .foregroundStyle(MainScreenPalette.textPrimary)

                    Text(item.description ?? "상세 커리큘럼이 없습니다.")
                        .font(MainScreenTypography.body)
                        .foregroundStyle(MainScreenPalette.textSecondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(MainScreenPalette.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }
}

private struct PostInfoBadge: View {
    let text: String
    let systemName: String

    var body: some View {
        Label(text, systemImage: systemName)
            .font(MainScreenTypography.chip)
            .foregroundStyle(MainScreenPalette.primaryBlue)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(
                MainScreenPalette.surface,
                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(MainScreenPalette.borderBlue, lineWidth: 1)
            )
    }
}

private struct ActivityDetailStateView: View {
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
        .padding(.horizontal, 24)
    }
}
