//
//  AppConfiguration.swift
//  Ditto
//
//  Created by 김기태 on 4/23/26.
//

import Foundation

struct AppConfiguration: Sendable {
    let baseURL: URL
    let apiKey: String

    init(baseURL: URL, apiKey: String) throws {
        guard !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppConfigurationError.missingValue(key: Key.apiKey.rawValue)
        }

        self.baseURL = baseURL
        self.apiKey = apiKey
    }

    init(bundle: Bundle = .main) throws {
        let baseURLString = try Self.requiredString(for: .baseURL, in: bundle)
        let apiKey = try Self.requiredString(for: .apiKey, in: bundle)

        guard let baseURL = URL(string: baseURLString) else {
            throw AppConfigurationError.invalidURL(key: Key.baseURL.rawValue, value: baseURLString)
        }

        try self.init(baseURL: baseURL, apiKey: apiKey)
    }
}

extension AppConfiguration {
    enum Key: String {
        case baseURL = "BASE_URL"
        case apiKey = "API_KEY"
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
}

enum AppConfigurationError: Error, Equatable {
    case missingValue(key: String)
    case invalidURL(key: String, value: String)
}
