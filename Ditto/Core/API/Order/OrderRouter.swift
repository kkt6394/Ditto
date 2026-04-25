//
//  OrderRouter.swift
//  Ditto
//
//  Created by Codex on 4/25/26.
//

import Foundation

enum OrderRouter: APIRouter {
    case create(OrderCreateRequestDTO)
    case list
}

extension OrderRouter {
    var path: String {
        "v1/orders"
    }

    var method: HTTPMethod {
        switch self {
        case .create:
            return .post
        case .list:
            return .get
        }
    }

    var body: Encodable? {
        switch self {
        case .create(let request):
            return request
        case .list:
            return nil
        }
    }

    var requiresAuthentication: Bool {
        true
    }
}
