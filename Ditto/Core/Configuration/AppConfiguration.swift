//
//  AppConfiguration.swift
//  Ditto
//
//  Created by 김기태 on 4/23/26.
//

import Foundation

// 앱 실행에 필요한 설정값을 한 곳에서 검증한다.
// Secrets.xcconfig 값은 빌드 시 Info.plist에 치환되고, 런타임에서는 Bundle을 통해 읽는다.
struct AppConfiguration: Sendable {
    let baseURL: URL
    let apiKey: String
    // 포트원 결제 SDK 호출 시 사용되는 가맹점 식별코드와 PG 코드.
    // 결제 진입 시점에만 필요하고 다른 기능에는 영향이 없으므로 옵셔널로 둔다.
    let impUserCode: String?
    let impPG: String?

    init(
        baseURL: URL,
        apiKey: String,
        impUserCode: String? = nil,
        impPG: String? = nil
    ) throws {
        // API key가 비어 있으면 모든 요청이 실패하므로 앱 시작 단계에서 빠르게 감지한다.
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppConfigurationError.missingValue(key: Key.apiKey.rawValue)
        }

        self.baseURL = baseURL
        self.apiKey = apiKey
        self.impUserCode = impUserCode
        self.impPG = impPG
    }

    init(bundle: Bundle = .main) throws {
        // 설정 누락을 초기에 발견하기 위해 String을 읽는 시점에 빈 값까지 함께 검사한다.
        let baseURLString = try Self.requiredString(for: .baseURL, in: bundle)
        let apiKey = try Self.requiredString(for: .apiKey, in: bundle)
        // 결제 식별값은 미설정 상태로도 앱이 실행돼야 하므로 옵셔널로 읽는다.
        let impUserCode = Self.optionalString(for: .impUserCode, in: bundle)
        let impPG = Self.optionalString(for: .impPG, in: bundle)

        guard let baseURL = URL(string: baseURLString) else {
            throw AppConfigurationError.invalidURL(key: Key.baseURL.rawValue, value: baseURLString)
        }

        try self.init(
            baseURL: baseURL,
            apiKey: apiKey,
            impUserCode: impUserCode,
            impPG: impPG
        )
    }
}

extension AppConfiguration {
    // Info.plist key 이름을 enum으로 묶어 문자열 오타를 줄인다.
    enum Key: String {
        case baseURL = "BASE_URL"
        case apiKey = "API_KEY"
        case impUserCode = "IMP_USER_CODE"
        case impPG = "IMP_PG"
    }

    private static func requiredString(for key: Key, in bundle: Bundle) throws -> String {
        guard let value = bundle.object(forInfoDictionaryKey: key.rawValue) as? String else {
            throw AppConfigurationError.missingValue(key: key.rawValue)
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedValue.isEmpty else {
            throw AppConfigurationError.missingValue(key: key.rawValue)
        }

        return trimmedValue
    }

    private static func optionalString(for key: Key, in bundle: Bundle) -> String? {
        guard let value = bundle.object(forInfoDictionaryKey: key.rawValue) as? String else {
            return nil
        }

        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}

enum AppConfigurationError: Error, Equatable {
    // Equatable을 채택해 설정 오류도 단위 테스트에서 정확히 비교할 수 있다.
    case missingValue(key: String)
    case invalidURL(key: String, value: String)
}
