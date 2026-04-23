//
//  AuthRequest.swift
//  Ditto
//
//  Created by 김기태 on 4/23/26.
//

// 회원가입 API의 request body다.
// Optional 값은 nil이면 JSONEncoder가 body에서 제외한다.
struct JoinRequest: Encodable, Equatable {
    let email: String
    let password: String
    let nick: String
    // 아래 세 값은 서버 문서상 optional이므로 nil이면 request body에서 빠진다.
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

// 이메일 로그인 API의 request body다.
// deviceToken은 필수가 아니므로 기본값을 nil로 둔다.
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
