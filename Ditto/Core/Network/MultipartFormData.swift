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
        let lineBreak = "\r\n"

        for part in parts {
            data.append("--\(boundary)\(lineBreak)")

            switch part {
            case .file(let name, let file):
                data.append(
                    """
                    Content-Disposition: form-data; name="\(name)"; filename="\(file.filename)"\(lineBreak)
                    Content-Type: \(file.mimeType)\(lineBreak)\(lineBreak)
                    """
                )
                data.append(file.data)
                data.append(lineBreak)
            case .text(let name, let value):
                data.append(
                    """
                    Content-Disposition: form-data; name="\(name)"\(lineBreak)\(lineBreak)
                    \(value)\(lineBreak)
                    """
                )
            }
        }

        data.append("--\(boundary)--\(lineBreak)")
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
