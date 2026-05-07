//
//  PaymentRouter.swift
//  Ditto
//
//  Created by Codex on 4/25/26.
//

import Foundation

enum PaymentRouter: APIRouter {
    case validate(PaymentValidationRequestDTO)
    case receipt(orderCode: String)
}

extension PaymentRouter {
    var path: String {
        switch self {
        case .validate:
            return "v1/payments/validation"
        case .receipt(let orderCode):
            return "v1/payments/\(orderCode)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .validate:
            return .post
        case .receipt:
            return .get
        }
    }

    var body: Encodable? {
        switch self {
        case .validate(let request):
            return request
        case .receipt:
            return nil
        }
    }

    var requiresAuthentication: Bool {
        true
    }

    // 결제 흐름은 사용자가 화면 앞에서 기다리는 상황이라 기본 60초는 너무 길다.
    // 30초로 줄여 일찍 실패시키고 ViewModel의 자동 재시도 루프에서 빠르게 다음 시도를 띄운다.
    var timeoutInterval: TimeInterval? {
        30
    }
}
