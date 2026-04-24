//
//  AuthTokens.swift
//  Ditto
//
//  Created by 김기태 on 4/24/26.
//

import Foundation

// accessToken과 refreshToken을 한 단위로 다루면 저장/갱신 흐름을 단순하게 유지할 수 있다.
struct AuthTokens: Codable, Equatable, Sendable {
    let accessToken: String
    let refreshToken: String
}
