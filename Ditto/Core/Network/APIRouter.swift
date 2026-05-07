//
//  APIRouter.swift
//  Ditto
//
//  Created by 김기태 on 4/23/26.
//

import Foundation

// 각 API endpoint가 URLRequest로 변환되기 위해 필요한 정보만 정의한다.
// 실제 URLRequest 생성과 실행은 NetworkManager가 담당한다.
protocol APIRouter {
    var path: String { get }
    var method: HTTPMethod { get }
    var queryItems: [URLQueryItem] { get }
    var headers: [String: String] { get }
    var body: Encodable? { get }
    var multipartFormData: MultipartFormData? { get }
    var requiresAuthentication: Bool { get }
    var allowsTokenRefreshRetry: Bool { get }
    // nil이면 URLSession 기본값(60초)을 사용한다. 결제처럼 빨리 실패해서 retry로 넘기는 게 나은
    // 호출은 여기에 짧은 값을 지정해 사용자가 오래 멈춰 있는 경험을 줄인다.
    var timeoutInterval: TimeInterval? { get }
}

extension APIRouter {
    // body/query/header가 없는 API는 라우터마다 빈 구현을 반복하지 않도록 기본값을 제공한다.
    var queryItems: [URLQueryItem] {
        []
    }

    var headers: [String: String] {
        [:]
    }

    var body: Encodable? {
        nil
    }

    var multipartFormData: MultipartFormData? {
        nil
    }

    var requiresAuthentication: Bool {
        false
    }

    var allowsTokenRefreshRetry: Bool {
        requiresAuthentication
    }

    var timeoutInterval: TimeInterval? {
        nil
    }
}

enum HTTPMethod: String {
    // rawValue를 HTTP 표준 method 문자열로 두면 URLRequest.httpMethod에 바로 넣을 수 있다.
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}
