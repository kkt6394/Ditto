//
//  UserRequest.swift
//  Ditto
//
//  Created by Codex on 4/25/26.
//

import Foundation

struct ProfileRequestDTO: Encodable, Equatable {
    let nick: String?
    let profileImage: String?
    let phoneNum: String?
    let introduction: String?
}

struct ProfileImageUploadRequestDTO: Equatable {
    let profile: MultipartFile
}
