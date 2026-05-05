//
//  ActivityComposeData.swift
//  Ditto
//
//  Created by Codex on 5/5/26.
//

import Foundation

// 액티비티 작성 화면의 동작 모드. 라우팅 페이로드는 단순한 activityId만 들고 다니고,
// .edit 진입 시 ViewModel이 detail API를 다시 호출해 prefill한다.
enum ActivityComposeMode: Hashable {
    case create
    case edit(activityId: String)
}

// 신규 첨부 사진 1개의 업로드 라이프사이클. PostComposeAttachment 패턴을 그대로 차용한다.
enum ActivityComposeAttachmentState: Equatable {
    case uploading
    case uploaded(path: String)
    case failed(message: String)
}

struct ActivityComposeAttachment: Identifiable, Equatable {
    let id: UUID
    let previewData: Data
    var state: ActivityComposeAttachmentState

    var uploadedPath: String? {
        if case .uploaded(let path) = state {
            return path
        }
        return nil
    }
}

// 일정(schedule) 입력 칸 1개. duration·description 모두 자유 텍스트.
struct ActivityComposeScheduleDraft: Identifiable, Equatable {
    let id: UUID
    var duration: String = ""
    var description: String = ""
}

// 편집 모드에서 서버가 이미 보유한 썸네일 경로를 표시·삭제 토글 단위로 관리한다.
struct ActivityComposeExistingThumbnail: Identifiable, Equatable {
    let id: UUID
    let path: String
    var isMarkedForDeletion: Bool
}
