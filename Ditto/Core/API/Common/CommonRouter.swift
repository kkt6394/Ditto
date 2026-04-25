//
//  CommonRouter.swift
//  Ditto
//
//  Created by Codex on 4/25/26.
//

import Foundation

enum CommonRouter: APIRouter {
    case common
}

extension CommonRouter {
    var path: String {
        "common"
    }

    var method: HTTPMethod {
        .get
    }
}
