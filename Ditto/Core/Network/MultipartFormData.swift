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

private extension Data {
    mutating func append(_ string: String) {
        append(Data(string.utf8))
    }
}
