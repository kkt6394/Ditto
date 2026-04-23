//
//  APIRouter.swift
//  Ditto
//
//  Created by 김기태 on 4/23/26.
//

import Foundation

protocol APIRouter {
    var path: String { get }
    var method: HTTPMethod { get }
    var queryItems: [URLQueryItem] { get }
    var headers: [String: String] { get }
    var body: Encodable? { get }
}

extension APIRouter {
    var queryItems: [URLQueryItem] {
        []
    }

    var headers: [String: String] {
        [:]
    }

    var body: Encodable? {
        nil
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}
