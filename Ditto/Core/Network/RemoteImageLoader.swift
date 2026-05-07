//
//  RemoteImageLoader.swift
//  Ditto
//
//  Created by 김기태 on 5/2/26.
//

import ImageIO
import SwiftUI
import UIKit

/// 원격 이미지 로딩 시 발생할 수 있는 오류
enum RemoteImageError: Error {
    case invalidStatus(Int)
    case decodeFailed
}

/// 인증 헤더가 필요한 이미지 GET을 책임지는 추상 인터페이스.
///
/// 토큰이 만료되면(서버 419) 호출자가 직접 처리하지 않고도 갱신 후 재시도까지
/// 일관되게 처리되도록 NetworkManager가 conform한다. SearchRemoteImage 등
/// 뷰는 환경에서 이 로더를 받아 호출한다.
protocol AuthenticatedImageLoading {
    func loadImage(_ request: URLRequest, pointSize: CGSize) async throws -> UIImage
}

private struct AuthenticatedImageLoaderKey: EnvironmentKey {
    static let defaultValue: (any AuthenticatedImageLoading)? = nil
}

extension EnvironmentValues {
    /// 토큰 갱신 흐름이 적용된 이미지 로더. 진입점(ContentView)에서 NetworkManager를 주입한다.
    /// 환경 주입이 없는 경로(프리뷰 등)에서는 nil이며, 호출 측이 기존 폴백 로더로 떨어진다.
    var imageLoader: (any AuthenticatedImageLoading)? {
        get { self[AuthenticatedImageLoaderKey.self] }
        set { self[AuthenticatedImageLoaderKey.self] = newValue }
    }
}

/// 원격 이미지를 표시 크기에 맞게 다운샘플링해 로드하는 유틸리티
///
/// ## 다운샘플링이란?
/// 서버 원본(보통 1~3MB JPEG)을 `UIImage(data:)`로 그대로 디코딩하면
/// 비압축 비트맵으로 풀린 4배 이상의 메모리를 차지한다. (예: 2000×2000 → 약 16MB)
/// 화면에는 작은 썸네일만 보이는데도 메모리는 풀 사이즈를 잡는다.
///
/// `ImageIO`의 `CGImageSourceCreateThumbnailAtIndex`는 원본을 풀로 디코딩하지 않고
/// 표시 크기에 필요한 픽셀만 디코딩해 메모리 사용량을 1/10~1/50로 줄인다.
enum RemoteImageLoader {

    /// 원본 데이터에서 표시 크기에 맞는 썸네일을 생성한다.
    /// - Parameters:
    ///   - data: 원본 이미지 데이터
    ///   - pointSize: 표시 크기 (포인트). 픽셀로 환산해 다운샘플링한다.
    ///   - scale: 디스플레이 스케일. nil이면 메인 스크린 스케일 사용.
    static func downsample(data: Data, pointSize: CGSize, scale: CGFloat? = nil) -> UIImage? {
        let displayScale = scale ?? UIScreen.main.scale
        // 가로/세로 중 큰 쪽의 픽셀 수를 기준으로 썸네일을 생성한다.
        // 비율은 자동으로 유지된다.
        let maxDimensionInPixels = max(pointSize.width, pointSize.height) * displayScale

        let sourceOptions: CFDictionary = [
            kCGImageSourceShouldCache: false  // 원본은 캐시하지 않음 — 다운샘플링 결과만 메모리에 둔다
        ] as CFDictionary

        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else {
            // ImageIO 실패 시 폴백 — 원본 사이즈로라도 표시
            return UIImage(data: data)
        }

        let downsampleOptions: CFDictionary = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,        // 다운샘플 결과만 즉시 디코딩
            kCGImageSourceCreateThumbnailWithTransform: true,  // EXIF 회전 정보 반영
            kCGImageSourceThumbnailMaxPixelSize: maxDimensionInPixels
        ] as CFDictionary

        guard let downsampledImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: downsampledImage, scale: displayScale, orientation: .up)
    }

    /// URLRequest 로 이미지를 받아 표시 크기로 다운샘플링한 `UIImage`를 반환한다.
    /// - Parameters:
    ///   - request: 인증 헤더가 포함된 URLRequest
    ///   - pointSize: 화면에 보일 크기 (포인트 단위)
    ///   - scale: 디스플레이 스케일. nil이면 메인 스크린 스케일 사용.
    static func load(
        request: URLRequest,
        pointSize: CGSize,
        scale: CGFloat? = nil
    ) async throws -> UIImage {
        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw RemoteImageError.invalidStatus(http.statusCode)
        }

        guard let image = downsample(data: data, pointSize: pointSize, scale: scale) else {
            throw RemoteImageError.decodeFailed
        }
        return image
    }
}
