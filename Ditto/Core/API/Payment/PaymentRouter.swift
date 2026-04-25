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
}
