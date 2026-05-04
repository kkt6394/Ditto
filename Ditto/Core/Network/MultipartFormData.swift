//
//  MultipartFormData.swift
//  Ditto
//
//  Created by Codex on 4/25/26.
//

import Foundation

// Swagger의 파일 업로드 endpoint를 공통 네트워크 계층에서 재사용할 수 있게 표현한다.
struct MultipartFormData {
    let parts: [Part]
}

extension MultipartFormData {
    enum Part {
        case file(name: String, file: MultipartFile)
        case text(name: String, value: String)
    }

    func encoded(boundary: String) -> Data {
        var data = Data()
        // RFC 7578에 따라 헤더와 본문 사이는 정확히 \r\n만 사용해야 한다.
        // 멀티라인 문자열은 라인 사이에 추가 \n을 끼워 넣어 일부 서버에서 거부되므로 한 줄씩 명시적으로 만든다.
        let crlf = "\r\n"

        for part in parts {
            data.append("--\(boundary)\(crlf)")

            switch part {
            case .file(let name, let file):
                data.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(file.filename)\"\(crlf)")
                data.append("Content-Type: \(file.mimeType)\(crlf)\(crlf)")
                data.append(file.data)
                data.append(crlf)
            case .text(let name, let value):
                data.append("Content-Disposition: form-data; name=\"\(name)\"\(crlf)\(crlf)")
                data.append("\(value)\(crlf)")
            }
        }

        data.append("--\(boundary)--\(crlf)")
        return data
    }
}

struct MultipartFile: Equatable {
    let filename: String
    let mimeType: String
    let data: Data
}

// 서버 정책에 맞춰 업로드 직전 파일 크기/개수를 사전 검증한다.
// 화면별 정밀 가공(다운샘플·재인코딩)은 별도 책임으로 두고, 여기서는 마지막 안전망 역할만 한다.
struct MultipartUploadLimit {
    let maxBytesPerFile: Int
    let maxFiles: Int

    static let profileImage = MultipartUploadLimit(maxBytesPerFile: 1 * 1024 * 1024, maxFiles: 1)
    static let activityFiles = MultipartUploadLimit(maxBytesPerFile: 5 * 1024 * 1024, maxFiles: 5)
    static let postFiles = activityFiles
    static let reviewFiles = activityFiles
    static let chatFiles = activityFiles
}

enum MultipartUploadError: Error, Equatable {
    case fileTooLarge(filename: String, maxBytes: Int)
    case tooManyFiles(maxFiles: Int)

    var userMessage: String {
        switch self {
        case .fileTooLarge(_, let maxBytes):
            let mb = Double(maxBytes) / (1024 * 1024)
            return String(format: "파일 크기는 최대 %.0fMB까지 가능합니다.", mb)
        case .tooManyFiles(let maxFiles):
            return "한 번에 최대 \(maxFiles)개까지 첨부할 수 있습니다."
        }
    }
}

extension Array where Element == MultipartFile {
    func validated(against limit: MultipartUploadLimit) throws -> Self {
        if count > limit.maxFiles {
            throw MultipartUploadError.tooManyFiles(maxFiles: limit.maxFiles)
        }
        if let oversized = first(where: { $0.data.count > limit.maxBytesPerFile }) {
            throw MultipartUploadError.fileTooLarge(filename: oversized.filename, maxBytes: limit.maxBytesPerFile)
        }
        return self
    }
}

extension MultipartFile {
    func validated(against limit: MultipartUploadLimit) throws -> MultipartFile {
        _ = try [self].validated(against: limit)
        return self
    }
}

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
