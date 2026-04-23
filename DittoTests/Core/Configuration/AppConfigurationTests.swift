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
        // Bundle 없이 직접 값으로 초기화하면 설정 검증 로직만 독립적으로 테스트할 수 있다.
        let baseURL = try #require(URL(string: "https://example.com"))

        let configuration = try AppConfiguration(baseURL: baseURL, apiKey: "test-key")

        #expect(configuration.baseURL == baseURL)
        #expect(configuration.apiKey == "test-key")
    }

    @Test func emptyAPIKeyThrowsMissingValueError() throws {
        // API key 누락은 네트워크 요청 전에 설정 단계에서 실패해야 원인 파악이 쉽다.
        let baseURL = try #require(URL(string: "https://example.com"))

        #expect(throws: AppConfigurationError.missingValue(key: "API_KEY")) {
            try AppConfiguration(baseURL: baseURL, apiKey: " ")
        }
    }
}
