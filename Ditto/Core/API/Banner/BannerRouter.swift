//
//  BannerRouter.swift
//  Ditto
//
//  Created by Codex on 4/25/26.
//

import Foundation

enum BannerRouter: APIRouter {
    case main
}

extension BannerRouter {
    var path: String {
        "v1/banners/main"
    }

    var method: HTTPMethod {
        .get
    }

    var requiresAuthentication: Bool {
        true
    }
}
