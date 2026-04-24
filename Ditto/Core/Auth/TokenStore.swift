//
//  TokenStore.swift
//  Ditto
//
//  Created by 김기태 on 4/24/26.
//

import Foundation
import Security

// 토큰 저장소 구현을 교체할 수 있게 해 두면 테스트에서는 메모리 저장소를 쉽게 주입할 수 있다.
protocol TokenStoring: Sendable {
    func loadTokens() throws -> AuthTokens?
    func saveTokens(_ tokens: AuthTokens) throws
    func deleteTokens() throws
}

enum TokenStoreError: Error, Equatable {
    case encodingFailed
    case decodingFailed
    case unhandledStatus(OSStatus)
}
