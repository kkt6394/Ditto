//
//  PostComposeData.swift
//  Ditto
//
//  Created by Codex on 4/29/26.
//

import Foundation

// 글쓰기 폼이 다루는 액티비티 후보. ActivityRouter.search 응답을 화면용으로 변환해 보관한다.
struct PostComposeActivityCandidate: Identifiable, Equatable {
    let id: String
    let title: String
    let country: String?
    let category: String?
}

// 사진 업로드 칸 1개의 상태. uploading 단계에서는 서버 응답 경로가 없고, uploaded 이후에 path가 채워진다.
enum PostComposeAttachmentState: Equatable {
    case uploading
    case uploaded(path: String)
    case failed(message: String)
}

struct PostComposeAttachment: Identifiable, Equatable {
    let id: UUID
    let previewData: Data
    var state: PostComposeAttachmentState

    var uploadedPath: String? {
        if case .uploaded(let path) = state {
            return path
        }
        return nil
    }
}

struct PostComposeInitialContext {
    let country: String
    let category: String
    let coordinate: UserCoordinate?
}
