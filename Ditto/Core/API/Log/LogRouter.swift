//
//  LogRouter.swift
//  Ditto
//
//  Created by Codex on 4/25/26.
//

import Foundation

enum LogRouter: APIRouter {
    case list
}

extension LogRouter {
    var path: String {
        "v1/log"
    }

    var method: HTTPMethod {
        .get
    }
}
