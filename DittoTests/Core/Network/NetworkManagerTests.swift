//
//  NetworkManagerTests.swift
//  DittoTests
//
//  Created by 김기태 on 4/24/26.
//

import Foundation
import Testing
@testable import Ditto

@MainActor
struct NetworkManagerTests {
    @Test func authenticatedRequestRefreshesTokenOn419AndRetriesOnce() async throws {
        let configuration = try AppConfiguration(
            baseURL: #require(URL(string: "https://example.com")),
            apiKey: "test-key"
        )
        let testID = UUID().uuidString
        let authManager = StubAuthManager(tokens: AuthTokens(accessToken: "expired-access", refreshToken: "refresh-token"))
        let session = makeSession(testID: testID)
        let networkManager = NetworkManager(configuration: configuration, authManager: authManager, session: session)
        var protectedRequestCount = 0

        URLProtocolStub.setRequestHandler(for: testID) { request in
            let url = try #require(request.url)

            switch url.path {
            case "/v1/protected":
                protectedRequestCount += 1

                if protectedRequestCount == 1 {
                    #expect(request.value(forHTTPHeaderField: "Authorization") == "expired-access")
                    return (
                        HTTPURLResponse(url: url, statusCode: 419, httpVersion: nil, headerFields: nil)!,
                        try makeErrorResponseData(message: "액세스 토큰이 만료되었습니다.")
                    )
                }

                #expect(request.value(forHTTPHeaderField: "Authorization") == "new-access")
                return (
                    HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    try JSONEncoder().encode(ProtectedResponse(value: "ok"))
                )
            case "/v1/auth/refresh":
                #expect(request.value(forHTTPHeaderField: "Authorization") == "expired-access")
                #expect(request.value(forHTTPHeaderField: "RefreshToken") == "refresh-token")
                #expect(request.value(forHTTPHeaderField: "SeSACKey") == "test-key")

                return (
                    HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    try makeRefreshResponseData(
                        accessToken: "new-access",
                        refreshToken: "new-refresh"
                    )
                )
            default:
                Issue.record("Unexpected request path: \(url.path)")
                throw StubNetworkTestError.unexpectedRequest
            }
        }
        defer {
            URLProtocolStub.removeRequestHandler(for: testID)
        }

        let response: ProtectedResponse = try await networkManager.request(ProtectedRouter())

        #expect(response == ProtectedResponse(value: "ok"))
        #expect(protectedRequestCount == 2)
        #expect(authManager.tokens == AuthTokens(accessToken: "new-access", refreshToken: "new-refresh"))
    }

    @Test func refreshFailureSignsOutAndKeepsOriginalError() async throws {
        let configuration = try AppConfiguration(
            baseURL: #require(URL(string: "https://example.com")),
            apiKey: "test-key"
        )
        let testID = UUID().uuidString
        let authManager = StubAuthManager(tokens: AuthTokens(accessToken: "expired-access", refreshToken: "refresh-token"))
        let session = makeSession(testID: testID)
        let networkManager = NetworkManager(configuration: configuration, authManager: authManager, session: session)
        var protectedRequestCount = 0

        URLProtocolStub.setRequestHandler(for: testID) { request in
            let url = try #require(request.url)

            switch url.path {
            case "/v1/protected":
                protectedRequestCount += 1

                return (
                    HTTPURLResponse(url: url, statusCode: 419, httpVersion: nil, headerFields: nil)!,
                    try makeErrorResponseData(message: "액세스 토큰이 만료되었습니다.")
                )
            case "/v1/auth/refresh":
                return (
                    HTTPURLResponse(url: url, statusCode: 418, httpVersion: nil, headerFields: nil)!,
                    try makeErrorResponseData(message: "리프레시 토큰이 만료되었습니다.")
                )
            default:
                Issue.record("Unexpected request path: \(url.path)")
                throw StubNetworkTestError.unexpectedRequest
            }
        }
        defer {
            URLProtocolStub.removeRequestHandler(for: testID)
        }

        do {
            let _: ProtectedResponse = try await networkManager.request(ProtectedRouter())
            Issue.record("Expected refresh failure to be thrown.")
        } catch let NetworkError.statusCode(statusCode, message, _) {
            #expect(statusCode == 418)
            #expect(message == "리프레시 토큰이 만료되었습니다.")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(protectedRequestCount == 1)
        #expect(authManager.tokens == nil)
    }
}

private struct ProtectedRouter: APIRouter {
    let path = "v1/protected"
    let method = HTTPMethod.get
    let requiresAuthentication = true
}

private struct ProtectedResponse: Codable, Equatable {
    let value: String
}

@MainActor
private final class StubAuthManager: AuthManaging {
    private(set) var tokens: AuthTokens?

    var isAuthenticated: Bool {
        tokens != nil
    }

    init(tokens: AuthTokens?) {
        self.tokens = tokens
    }

    func authenticate(with tokens: AuthTokens) throws {
        self.tokens = tokens
    }

    func signOut() throws {
        tokens = nil
    }
}

private enum StubNetworkTestError: Error {
    case unexpectedRequest
}

private func makeSession(testID: String) -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [URLProtocolStub.self]
    configuration.httpAdditionalHeaders = ["X-Test-ID": testID]
    return URLSession(configuration: configuration)
}

private func makeErrorResponseData(message: String) throws -> Data {
    try JSONSerialization.data(withJSONObject: ["message": message])
}

private func makeRefreshResponseData(accessToken: String, refreshToken: String) throws -> Data {
    try JSONSerialization.data(
        withJSONObject: [
            "accessToken": accessToken,
            "refreshToken": refreshToken
        ]
    )
}

private final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    fileprivate typealias RequestHandler = (URLRequest) throws -> (HTTPURLResponse, Data)
    private static let lock = NSLock()
    private static var requestHandlers: [String: RequestHandler] = [:]

    fileprivate static func setRequestHandler(for testID: String, handler: @escaping RequestHandler) {
        lock.lock()
        defer { lock.unlock() }
        requestHandlers[testID] = handler
    }

    fileprivate static func removeRequestHandler(for testID: String) {
        lock.lock()
        defer { lock.unlock() }
        requestHandlers[testID] = nil
    }

    fileprivate static func requestHandler(for testID: String) -> RequestHandler? {
        lock.lock()
        defer { lock.unlock() }
        return requestHandlers[testID]
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let testID = request.value(forHTTPHeaderField: "X-Test-ID"),
              let handler = Self.requestHandler(for: testID) else {
            client?.urlProtocol(self, didFailWithError: StubNetworkTestError.unexpectedRequest)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
