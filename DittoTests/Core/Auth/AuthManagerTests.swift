//
//  AuthManagerTests.swift
//  DittoTests
//
//  Created by 김기태 on 4/24/26.
//

import Testing
@testable import Ditto

@MainActor
struct AuthManagerTests {
    @Test func initLoadsStoredTokens() {
        let tokenStore = InMemoryTokenStore(tokens: .fixture)

        let authManager = AuthManager(tokenStore: tokenStore)

        #expect(authManager.tokens == .fixture)
        #expect(authManager.isAuthenticated)
    }

    @Test func authenticatePersistsTokensAndUpdatesAuthenticationState() throws {
        let tokenStore = InMemoryTokenStore()
        let authManager = AuthManager(tokenStore: tokenStore)

        try authManager.authenticate(with: .fixture)

        #expect(authManager.tokens == .fixture)
        #expect(authManager.isAuthenticated)
        #expect(tokenStore.tokens == .fixture)
    }

    @Test func signOutClearsStoredTokensAndUpdatesAuthenticationState() throws {
        let tokenStore = InMemoryTokenStore(tokens: .fixture)
        let authManager = AuthManager(tokenStore: tokenStore)

        try authManager.signOut()

        #expect(authManager.tokens == nil)
        #expect(!authManager.isAuthenticated)
        #expect(tokenStore.tokens == nil)
    }
}

private final class InMemoryTokenStore: @unchecked Sendable, TokenStoring {
    var tokens: AuthTokens?

    init(tokens: AuthTokens? = nil) {
        self.tokens = tokens
    }

    func loadTokens() throws -> AuthTokens? {
        tokens
    }

    func saveTokens(_ tokens: AuthTokens) throws {
        self.tokens = tokens
    }

    func deleteTokens() throws {
        tokens = nil
    }
}

private extension AuthTokens {
    static let fixture = AuthTokens(accessToken: "access-token", refreshToken: "refresh-token")
}
