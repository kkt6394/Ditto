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

    // 주문 생성도 결제 화면에서 사용자가 대기하는 호출이라 기본 60초보다 짧게 둔다.
    // 일찍 실패하면 사용자가 다시 누를 기회가 빨리 오고, 검증과 일관된 timeout 정책을 갖는다.
    var timeoutInterval: TimeInterval? {
        switch self {
        case .create:
            return 30
        case .list:
            return nil
        }
    }
}
