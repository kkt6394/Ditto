//
//  LogModels.swift
//  Ditto
//
//  Created by Codex on 4/25/26.
//

import Foundation

struct LogDTO: Decodable, Equatable {
    let date: String?
    let name: String?
    let method: String?
    let routePath: String?
    let body: String?
    let contentType: String?
    let statusCode: String?
}

struct LogListResponseDTO: Decodable, Equatable {
    let count: Int?
    let logs: [LogDTO]?
}
