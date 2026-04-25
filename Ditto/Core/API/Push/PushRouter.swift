//
//  PushRouter.swift
//  Ditto
//
//  Created by Codex on 4/25/26.
//

import Foundation

enum PushRouter: APIRouter {
    case send(PushNotificationRequestDTO)
}

extension PushRouter {
    var path: String {
        "v1/notifications/push"
    }

    var method: HTTPMethod {
        .post
    }

    var body: Encodable? {
        switch self {
        case .send(let request):
            return request
        }
    }

    var requiresAuthentication: Bool {
        true
    }
}
