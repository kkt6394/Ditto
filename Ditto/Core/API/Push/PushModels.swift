//
//  PushModels.swift
//  Ditto
//
//  Created by Codex on 4/25/26.
//

import Foundation

struct PushNotificationRequestDTO: Encodable, Equatable {
    let userId: String
    let title: String
    let subtitle: String?
    let body: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case title
        case subtitle
        case body
    }
}
