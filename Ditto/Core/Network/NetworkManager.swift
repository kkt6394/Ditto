//
//  NetworkManager.swift
//  Ditto
//
//  Created by 김기태 on 4/23/26.
//

import Foundation

protocol NetworkManaging {
    func request<T: Decodable>(_ router: APIRouter) async throws -> T
    func send(_ router: APIRouter) async throws
}

final class NetworkManager: NetworkManaging {
    private let configuration: AppConfiguration
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        configuration: AppConfiguration,
        session: URLSession = .shared,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.configuration = configuration
        self.session = session
        self.encoder = encoder
        self.decoder = decoder
    }

    func request<T: Decodable>(_ router: APIRouter) async throws -> T {
        let data = try await data(for: router)

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }

    func send(_ router: APIRouter) async throws {
        _ = try await data(for: router)
    }
}

private extension NetworkManager {
    func data(for router: APIRouter) async throws -> Data {
        let request = try makeRequest(from: router)

        do {
            let (data, response) = try await session.data(for: request)
            try validate(response: response, data: data)
            return data
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.requestFailed(error)
        }
    }

    func makeRequest(from router: APIRouter) throws -> URLRequest {
        guard let url = makeURL(path: router.path, queryItems: router.queryItems) else {
            throw NetworkError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = router.method.rawValue
        request.setValue(configuration.apiKey, forHTTPHeaderField: "SesacKey")

        router.headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let body = router.body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encode(body)
        }

        return request
    }

    func makeURL(path: String, queryItems: [URLQueryItem]) -> URL? {
        guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let routePath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let fullPath = [basePath, routePath]
            .filter { !$0.isEmpty }
            .joined(separator: "/")

        components.path = "/" + fullPath

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        return components.url
    }

    func encode(_ body: Encodable) throws -> Data {
        do {
            return try encoder.encode(AnyEncodable(body))
        } catch {
            throw NetworkError.encodingFailed(error)
        }
    }

    func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw NetworkError.statusCode(httpResponse.statusCode, data: data)
        }
    }
}

private struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void

    init(_ value: Encodable) {
        encodeValue = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeValue(encoder)
    }
}
