//
//  UserResponse.swift
//  Ditto
//
//  Created by Codex on 4/25/26.
//

import Foundation

struct MyInfoResponseDTO: Decodable, Equatable {
    let userId: String
    let email: String
    let nick: String
    let profileImage: String?
    let phoneNum: String?
    let introduction: String?
}

struct UserInfoResponseDTO: Decodable, Equatable {
    let userId: String
    let nick: String
    let profileImage: String?
    let introduction: String?
}

struct UserInfoListResponseDTO: Decodable, Equatable {
    let data: [UserInfoResponseDTO]
}

struct FollowResponseDTO: Decodable, Equatable {
    let nick: String
    let opponentNick: String
    let followingStatus: Bool
}

struct ProfileImageUploadResponseDTO: Decodable, Equatable {
    let profileImage: String?
}
