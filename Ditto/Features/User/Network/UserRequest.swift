//
//  UserRequest.swift
//  Ditto
//
//  Created by 김기태 on 4/23/26.
//

struct JoinRequest: Encodable, Equatable {
    let email: String
    let password: String
    let nick: String
    let phoneNum: String?
    let introduction: String?
    let deviceToken: String?

    init(
        email: String,
        password: String,
        nick: String,
        phoneNum: String? = nil,
        introduction: String? = nil,
        deviceToken: String? = nil
    ) {
        self.email = email
        self.password = password
        self.nick = nick
        self.phoneNum = phoneNum
        self.introduction = introduction
        self.deviceToken = deviceToken
    }
}

struct LoginRequest: Encodable, Equatable {
    let email: String
    let password: String
    let deviceToken: String?

    init(email: String, password: String, deviceToken: String? = nil) {
        self.email = email
        self.password = password
        self.deviceToken = deviceToken
    }
}
