//
//  ProfileModels.swift
//  Ditto
//
//  Created by Codex on 5/1/26.
//

import Foundation

// 화면이 사용할 프로필 도메인 타입. 서버 DTO와 분리해 두면 화면 입장에서
// 옵셔널 처리·표시값 가공을 한 곳에서 끝낼 수 있다.
struct ProfileSummary: Equatable {
    let userId: String
    let email: String
    let nick: String
    let profileImagePath: String?
    let phoneNumber: String?
    let introduction: String?
}

extension ProfileSummary {
    init(dto: MyInfoResponseDTO) {
        self.userId = dto.userId
        self.email = dto.email
        self.nick = dto.nick
        self.profileImagePath = dto.profileImage
        self.phoneNumber = dto.phoneNum
        self.introduction = dto.introduction
    }

    var displayIntroduction: String {
        guard let introduction, !introduction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "아직 소개가 등록되지 않았습니다."
        }
        return introduction
    }

    var displayPhoneNumber: String {
        guard let phoneNumber, !phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "미등록"
        }
        return phoneNumber
    }
}

// 내 포스트·좋아요 미니 섹션에 쓰는 아주 가벼운 카드 표현.
struct ProfilePostPreview: Identifiable, Equatable {
    let id: String
    let title: String
    let summary: String
    let category: String
    let location: String
    let imageRequest: URLRequest?
    let likeCount: Int
}
