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
    // 마지막 sign-out이 어떤 사유로 발생했는지 화면 단에서 한 번만 소비할 수 있게 노출한다.
    var lastSignOutReason: SignOutReason? { get }

    func authenticate(with tokens: AuthTokens) throws
    func signOut(reason: SignOutReason) throws
    // 한 번 안내한 뒤에는 사유를 비워, 같은 토스트가 반복 노출되지 않도록 한다.
    func consumeSignOutReason()
}

extension AuthManaging {
    // 사용자 명시적 로그아웃은 사유 표시가 필요 없으므로 기본값으로 .userInitiated을 사용한다.
    func signOut() throws {
        try signOut(reason: .userInitiated)
    }
}

// 화면이 sign-out 직후 어떤 안내를 줄지 결정하기 위한 사유 분류다.
enum SignOutReason: Equatable, Sendable {
    case userInitiated
    case sessionExpired
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
    // 인증이 풀린 사유를 LoginView에 한 번만 노출하기 위한 일회성 상태다.
    private(set) var lastSignOutReason: SignOutReason?

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
            // 새로 인증되면 이전 만료 안내가 남아 있어도 더 이상 보여줄 필요가 없다.
            lastSignOutReason = nil
        } catch {
            throw AuthManagerError.tokenSaveFailed
        }
    }

    func signOut(reason: SignOutReason) throws {
        do {
            try tokenStore.deleteTokens()
            tokens = nil
            lastSignOutReason = reason
        } catch {
            throw AuthManagerError.tokenDeleteFailed
        }
    }

    func consumeSignOutReason() {
        lastSignOutReason = nil
    }
}
