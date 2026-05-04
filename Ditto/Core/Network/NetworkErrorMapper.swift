//
//  NetworkErrorMapper.swift
//  Ditto
//
//  Created by Codex on 5/4/26.
//

import Foundation

// 각 ViewModel/Store가 자체 makeErrorMessage를 들고 있던 것을 한 곳으로 모은다.
// NetworkError, AppConfigurationError, MultipartUploadError 등 도메인 에러를 일관된 사용자 메시지로 변환한다.
enum NetworkErrorMapper {
    static func userMessage(from error: Error, fallback: String) -> String {
        if let validationError = error as? MultipartUploadError {
            return validationError.userMessage
        }

        if let networkError = error as? NetworkError {
            return networkUserMessage(from: networkError, fallback: fallback)
        }

        if let configurationError = error as? AppConfigurationError {
            switch configurationError {
            case .missingValue, .invalidURL:
                return "API 설정값을 확인해 주세요."
            }
        }

        if let authError = error as? AuthManagerError {
            switch authError {
            case .tokenSaveFailed:
                return "인증 정보를 저장할 수 없습니다."
            case .tokenDeleteFailed:
                return "인증 정보를 삭제할 수 없습니다."
            }
        }

        return fallback
    }

    static func networkUserMessage(from error: NetworkError, fallback: String) -> String {
        switch error {
        case .missingAuthenticationToken:
            return "로그인이 필요합니다."
        case .statusCode(_, let message, _):
            return message ?? fallback
        case .requestFailed:
            return "네트워크 연결을 확인해 주세요."
        case .decodingFailed:
            return fallback
        case .invalidURL:
            return "요청 주소가 올바르지 않습니다."
        case .invalidResponse:
            return "서버 응답을 확인할 수 없습니다."
        case .encodingFailed:
            return "요청 데이터를 만들 수 없습니다."
        }
    }
}
