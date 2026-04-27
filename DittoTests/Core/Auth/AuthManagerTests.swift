//
//  AuthManagerTests.swift
//  DittoTests
//
//  Created by 김기태 on 4/24/26.
//

import Foundation
import Testing
@testable import Ditto

@MainActor
struct AuthManagerTests {
    @Test func initLoadsStoredTokens() {
        let tokenStore = InMemoryTokenStore(tokens: .fixture)
        let userDefaults = makePreparedUserDefaults()

        let authManager = AuthManager(tokenStore: tokenStore, userDefaults: userDefaults)

        #expect(authManager.tokens == .fixture)
        #expect(authManager.isAuthenticated)
    }

    @Test func initClearsStoredTokensOnFirstLaunchAfterInstall() {
        let tokenStore = InMemoryTokenStore(tokens: .fixture)
        let userDefaults = makeUserDefaults()

        let authManager = AuthManager(tokenStore: tokenStore, userDefaults: userDefaults)

        #expect(authManager.tokens == nil)
        #expect(!authManager.isAuthenticated)
        #expect(tokenStore.tokens == nil)
    }

    @Test func initKeepsStoredTokensAfterFirstLaunchPreparation() {
        let tokenStore = InMemoryTokenStore(tokens: .fixture)
        let userDefaults = makePreparedUserDefaults()

        let authManager = AuthManager(tokenStore: tokenStore, userDefaults: userDefaults)

        #expect(authManager.tokens == .fixture)
        #expect(authManager.isAuthenticated)
        #expect(tokenStore.tokens == .fixture)
    }

    @Test func authenticatePersistsTokensAndUpdatesAuthenticationState() throws {
        let tokenStore = InMemoryTokenStore()
        let userDefaults = makePreparedUserDefaults()
        let authManager = AuthManager(tokenStore: tokenStore, userDefaults: userDefaults)

        try authManager.authenticate(with: .fixture)

        #expect(authManager.tokens == .fixture)
        #expect(authManager.isAuthenticated)
        #expect(tokenStore.tokens == .fixture)
    }

    @Test func signOutClearsStoredTokensAndUpdatesAuthenticationState() throws {
        let tokenStore = InMemoryTokenStore(tokens: .fixture)
        let userDefaults = makePreparedUserDefaults()
        let authManager = AuthManager(tokenStore: tokenStore, userDefaults: userDefaults)

        try authManager.signOut()

        #expect(authManager.tokens == nil)
        #expect(!authManager.isAuthenticated)
        #expect(tokenStore.tokens == nil)
    }
}

private func makePreparedUserDefaults() -> UserDefaults {
    let userDefaults = makeUserDefaults()
    userDefaults.set(true, forKey: "auth.didPrepareKeychain")
    return userDefaults
}

private func makeUserDefaults() -> UserDefaults {
    let suiteName = "AuthManagerTests.\(UUID().uuidString)"
    guard let userDefaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("UserDefaults suite 생성에 실패했습니다.")
        return .standard
    }

    userDefaults.removePersistentDomain(forName: suiteName)
    return userDefaults
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
