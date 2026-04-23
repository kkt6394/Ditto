//
//  UserRouterTests.swift
//  DittoTests
//
//  Created by 김기태 on 4/23/26.
//

import Foundation
import Testing
@testable import Ditto

struct UserRouterTests {
    @Test func joinRouterUsesPostMethodAndJoinPath() {
        let router = UserRouter.join(
            email: "ditto@example.com",
            password: "password123",
            nick: "ditto"
        )

        #expect(router.method == .post)
        #expect(router.path == "v1/user/join")
    }

    @Test func loginRouterUsesPostMethodAndLoginPath() {
        let router = UserRouter.login(email: "ditto@example.com", password: "password123")

        #expect(router.method == .post)
        #expect(router.path == "v1/users/login")
    }

    @Test func loginBodyOmitsNilDeviceToken() throws {
        let router = UserRouter.login(email: "ditto@example.com", password: "password123")
        let body = try #require(router.body)
        let data = try JSONEncoder().encode(AnyEncodable(body))
        let dictionary = try #require(try JSONSerialization.jsonObject(with: data) as? [String: String])

        #expect(dictionary["email"] == "ditto@example.com")
        #expect(dictionary["password"] == "password123")
        #expect(dictionary["deviceToken"] == nil)
    }
}

private struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void

    init(_ value: Encodable) {
        encodeValue = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeValue(encoder)
    }
}
