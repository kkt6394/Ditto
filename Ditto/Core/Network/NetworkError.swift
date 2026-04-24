//
//  NetworkError.swift
//  Ditto
//
//  Created by 김기태 on 4/23/26.
//

import Foundation

// 네트워크 계층에서 발생한 오류를 ViewModel이 구분해서 처리할 수 있게 만든다.
enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case missingAuthenticationToken
    // 서버가 내려준 message는 사용자 안내 문구나 디버깅 정보로 활용할 수 있다.
    case statusCode(Int, message: String?, data: Data)
    case encodingFailed(Error)
    case decodingFailed(Error)
    // DNS, ATS, TLS, 오프라인 등 URLSession 단계의 실패는 원본 Error를 보존한다.
    case requestFailed(Error)
}

// 400, 409처럼 실패 응답에서도 서버가 내려주는 공통 message 형식이다.
struct APIErrorResponse: Decodable, Equatable {
    let message: String
}
