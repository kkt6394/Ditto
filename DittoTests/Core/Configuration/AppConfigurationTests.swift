//
//  AppConfigurationTests.swift
//  DittoTests
//
//  Created by 김기태 on 4/23/26.
//

import Foundation
import Testing
@testable import Ditto

struct AppConfigurationTests {
    @Test func validConfigurationStoresBaseURLAndAPIKey() throws {
        let baseURL = try #require(URL(string: "https://example.com"))

        let configuration = try AppConfiguration(baseURL: baseURL, apiKey: "test-key")

        #expect(configuration.baseURL == baseURL)
        #expect(configuration.apiKey == "test-key")
    }

    @Test func emptyAPIKeyThrowsMissingValueError() throws {
        let baseURL = try #require(URL(string: "https://example.com"))

        #expect(throws: AppConfigurationError.missingValue(key: "API_KEY")) {
            try AppConfiguration(baseURL: baseURL, apiKey: " ")
        }
    }
}
