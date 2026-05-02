//
//  MainBannerWebViewLauncher.swift
//  Ditto
//
//  Created by Codex on 5/2/26.
//

import Foundation
import SwiftUI

// sheet(item:)는 Identifiable이 필요해 URL을 감싸는 작은 wrapper를 둔다.
struct BannerWebViewPresentation: Identifiable {
    let id = UUID()
    let url: URL
}

// 명세상 payload.type이 WEBVIEW일 때만 웹뷰를 띄우고, value가 절대 URL이면 그대로,
// 상대 경로면 baseURL과 합쳐 절대 URL을 만든다. 그 외 type은 무시한다.
enum BannerWebViewLauncher {
    @MainActor
    @ViewBuilder
    static func makeWebView(
        for presentation: BannerWebViewPresentation,
        authManager: any AuthManaging
    ) -> some View {
        if let configuration = try? AppConfiguration() {
            SeSACWebView(
                url: presentation.url,
                authManager: authManager,
                configuration: configuration
            )
        }
    }

    static func presentation(for banner: MainBanner) -> BannerWebViewPresentation? {
        guard banner.payloadType.uppercased() == "WEBVIEW" else {
            return nil
        }

        guard let url = makeURL(from: banner.payloadValue) else {
            return nil
        }

        return BannerWebViewPresentation(url: url)
    }

    private static func makeURL(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }

        guard let configuration = try? AppConfiguration() else {
            return nil
        }

        return ActivityFormatting.makeImageURL(from: trimmed, baseURL: configuration.baseURL)
    }
}
