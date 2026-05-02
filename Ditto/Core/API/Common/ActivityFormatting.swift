//
//  ActivityFormatting.swift
//  Ditto
//
//  Created by 김기태 on 5/2/26.
//

import Foundation

/// MainViewModel·SearchViewModel·ProfileViewModel·KeepStore에서 중복으로 사용되던
/// 액티비티 표시용 포맷팅 유틸리티를 모아둔 namespace.
/// 각 ViewModel이 자기 고유 매핑 로직(`makeNewActivity`, `makeActivity` 등)에 집중할 수 있도록
/// 공통 텍스트/URL/경로 처리만 분리한다.
enum ActivityFormatting {

    // MARK: - Text Formatting

    /// 국가/도시명을 결합해 표시한다. 둘 중 하나만 있으면 해당 값만, 둘 다 비면 빈 문자열.
    static func combineCountryAndCity(country: String?, city: String) -> String {
        [country, city]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    /// 위치 텍스트 — country가 비어 있으면 안내 문구로 폴백한다.
    static func makeLocationText(country: String?) -> String {
        (country ?? "").ifEmpty("위치 정보 없음")
    }

    /// 가격 표시 — 천 단위 구분자 + "원" 접미사.
    static func makePriceText(_ price: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0

        let numberText = formatter.string(from: NSNumber(value: price)) ?? "\(Int(price))"
        return "\(numberText)원"
    }

    // MARK: - Path Predicates

    /// 이미지 확장자(jpg, jpeg, png, webp) 여부 판별.
    static func isImagePath(_ path: String) -> Bool {
        let lowercasedPath = path.lowercased()

        return [".jpg", ".jpeg", ".png", ".webp"].contains { imageExtension in
            lowercasedPath.hasSuffix(imageExtension)
        }
    }

    /// 영상 경로 여부 — `video://` 접두사 또는 동영상 확장자.
    static func isVideoPath(_ path: String) -> Bool {
        let lowercasedPath = path.lowercased()

        if lowercasedPath.hasPrefix("video://") {
            return true
        }

        return [".mp4", ".mov", ".m4v", ".m3u8"].contains { videoExtension in
            lowercasedPath.hasSuffix(videoExtension)
        }
    }

    /// `video://` 스킴에서 video id를 추출한다. 일반 경로는 nil.
    static func videoId(from path: String) -> String? {
        guard path.hasPrefix("video://") else {
            return nil
        }

        let videoId = String(path.dropFirst("video://".count))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return videoId.isEmpty ? nil : videoId
    }

    /// 썸네일 배열에서 첫 번째 이미지 경로만 골라낸다.
    static func firstImageThumbnail(from thumbnails: [String]) -> String? {
        thumbnails.first { thumbnail in
            isImagePath(thumbnail)
        }
    }

    // MARK: - URL & Request

    /// 상대 경로 thumbnail을 baseURL과 결합해 절대 URL을 만든다.
    /// `data/`로 시작하는 경로는 v1 prefix를 자동 부여한다.
    static func makeImageURL(from thumbnailPath: String, baseURL: URL) -> URL? {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var imagePath = thumbnailPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        if imagePath.hasPrefix("data/") {
            imagePath = "v1/" + imagePath
        }

        components.path = "/" + [basePath, imagePath]
            .filter { !$0.isEmpty }
            .joined(separator: "/")

        return components.url
    }

    /// 인증 헤더가 포함된 URLRequest를 생성한다.
    /// thumbnailPath가 절대 URL(scheme 포함)이면 그대로 사용하고, 상대 경로면 baseURL과 합친다.
    static func makeImageRequest(
        from thumbnailPath: String?,
        configuration: AppConfiguration,
        accessToken: String?
    ) -> URLRequest? {
        guard let thumbnailPath, !thumbnailPath.isEmpty else {
            return nil
        }

        let imageURL: URL?

        if let url = URL(string: thumbnailPath), url.scheme != nil {
            imageURL = url
        } else {
            imageURL = makeImageURL(from: thumbnailPath, baseURL: configuration.baseURL)
        }

        guard let imageURL else {
            return nil
        }

        var request = URLRequest(url: imageURL)
        request.setValue(configuration.apiKey, forHTTPHeaderField: "SeSACKey")

        if let accessToken {
            request.setValue(accessToken, forHTTPHeaderField: "Authorization")
        }

        return request
    }
}

// MARK: - String helper

extension String {
    /// 빈 문자열이면 fallback을 반환한다. ActivityFormatting 등에서 표시 텍스트 폴백용.
    func ifEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}
