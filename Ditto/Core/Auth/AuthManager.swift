//
//  AuthManager.swift
//  Ditto
//
//  Created by 김기태 on 4/24/26.
//

import Foundation
import Observation

@MainActor
protocol AuthManaging: AnyObject {
    var isAuthenticated: Bool { get }
    var tokens: AuthTokens? { get }

    func authenticate(with tokens: AuthTokens) throws
    func signOut() throws
}

enum AuthManagerError: Error {
    case tokenSaveFailed
    case tokenDeleteFailed
}

// 화면은 AuthManager의 인증 상태만 보고, 실제 저장 위치는 TokenStore 구현체가 담당한다.
@MainActor
@Observable
final class AuthManager: AuthManaging {
    private let tokenStore: any TokenStoring
    private(set) var tokens: AuthTokens?

    var isAuthenticated: Bool {
        tokens != nil
    }

    convenience init() {
        self.init(tokenStore: KeychainTokenStore())
    }

    init(tokenStore: any TokenStoring) {
        self.tokenStore = tokenStore
        // 저장 토큰을 읽지 못하더라도 앱 자체는 시작할 수 있어야 하므로 실패 시 비로그인 상태로 둔다.
        tokens = try? tokenStore.loadTokens()
    }

    func authenticate(with tokens: AuthTokens) throws {
        do {
            try tokenStore.saveTokens(tokens)
            self.tokens = tokens
        } catch {
            throw AuthManagerError.tokenSaveFailed
        }
    }

    func signOut() throws {
        do {
            try tokenStore.deleteTokens()
            tokens = nil
        } catch {
            throw AuthManagerError.tokenDeleteFailed
        }
    }
}
