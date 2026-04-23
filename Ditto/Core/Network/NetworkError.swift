//
//  NetworkError.swift
//  Ditto
//
//  Created by 김기태 on 4/23/26.
//

import Foundation

enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case statusCode(Int, data: Data)
    case encodingFailed(Error)
    case decodingFailed(Error)
    case requestFailed(Error)
}
