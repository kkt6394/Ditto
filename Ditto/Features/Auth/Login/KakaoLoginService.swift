//
//  KakaoLoginService.swift
//  Ditto
//
//  Created by Codex on 4/27/26.
//

import Foundation
import KakaoSDKAuth
import KakaoSDKUser

@MainActor
protocol KakaoLoginServicing {
    func login() async throws -> String
}

enum KakaoLoginServiceError: Error {
    case missingNativeAppKey
    case missingOAuthToken
}

struct KakaoLoginService: KakaoLoginServicing {
    func login() async throws -> String {
        guard Bundle.main.kakaoNativeAppKey != nil else {
            throw KakaoLoginServiceError.missingNativeAppKey
        }

        return try await withCheckedThrowingContinuation { continuation in
            let completion: (OAuthToken?, Error?) -> Void = { oauthToken, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let accessToken = oauthToken?.accessToken else {
                    continuation.resume(throwing: KakaoLoginServiceError.missingOAuthToken)
                    return
                }

                continuation.resume(returning: accessToken)
            }

            // 카카오톡이 있으면 앱 로그인, 없으면 카카오계정 웹 로그인으로 이어간다.
            if UserApi.isKakaoTalkLoginAvailable() {
                UserApi.shared.loginWithKakaoTalk(completion: completion)
            } else {
                UserApi.shared.loginWithKakaoAccount(completion: completion)
            }
        }
    }
}

extension Bundle {
    var kakaoNativeAppKey: String? {
        guard let value = object(forInfoDictionaryKey: "KAKAO_NATIVE_APP_KEY") as? String else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
