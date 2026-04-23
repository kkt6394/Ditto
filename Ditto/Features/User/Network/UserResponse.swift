//
//  UserResponse.swift
//  Ditto
//
//  Created by 김기태 on 4/23/26.
//

struct JoinResponse: Decodable, Equatable {
    let userID: String
    let email: String
    let nick: String
    let accessToken: String
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case email
        case nick
        case accessToken
        case refreshToken
    }
}

struct LoginResponse: Decodable, Equatable {
    let userID: String
    let email: String
    let nick: String
    let accessToken: String
    let refreshToken: String
    let profileImage: String?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case email
        case nick
        case accessToken
        case refreshToken
        case profileImage
    }
}
