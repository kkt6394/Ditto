//
//  NetworkManager.swift
//  Ditto
//
//  Created by 김기태 on 4/23/26.
//

import Foundation

// ViewModel/Repository가 NetworkManager 구현체에 직접 의존하지 않도록 분리한 인터페이스다.
protocol NetworkManaging {
    func request<T: Decodable>(_ router: APIRouter) async throws -> T
    func send(_ router: APIRouter) async throws
}

final class NetworkManager: NetworkManaging {
    private let configuration: AppConfiguration
    private let authManager: any AuthManaging
    // URLSession을 주입받게 하면 실제 통신 대신 테스트용 session으로 교체할 수 있다.
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    convenience init(
        configuration: AppConfiguration,
        session: URLSession = .shared,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = NetworkManager.makeDefaultDecoder()
    ) {
        self.init(
            configuration: configuration,
            authManager: AuthManager(),
            session: session,
            encoder: encoder,
            decoder: decoder
        )
    }

    init(
        configuration: AppConfiguration,
        authManager: any AuthManaging,
        session: URLSession = .shared,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = NetworkManager.makeDefaultDecoder()
    ) {
        self.configuration = configuration
        self.authManager = authManager
        self.session = session
        self.encoder = encoder
        self.decoder = decoder
    }

    func request<T: Decodable>(_ router: APIRouter) async throws -> T {
        // router로 요청을 만들고, 성공 응답 body를 호출자가 원하는 타입으로 디코딩한다.
        let data = try await data(for: router)

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }

    func send(_ router: APIRouter) async throws {
        // 응답 body가 필요 없는 API는 성공 여부만 검증한다.
        _ = try await data(for: router)
    }

    static func makeChatSocketDecoder() -> JSONDecoder {
        makeDefaultDecoder()
    }
}

private extension NetworkManager {
    static func makeDefaultDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        // Swagger 응답은 snake_case와 camelCase가 섞여 있어 변환 전략을 기본으로 둔다.
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    func data(for router: APIRouter) async throws -> Data {
        let request = try makeRequest(from: router)

        do {
            return try await perform(request: request)
        } catch let NetworkError.statusCode(statusCode, _, _)
            where statusCode == 419 && router.allowsTokenRefreshRetry {
            do {
                try await refreshTokens()
            } catch {
                try signOutIfRefreshExpired(with: error)
                throw error
            }

            let retryRequest = try makeRequest(from: router)
            return try await perform(request: retryRequest)
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
        // 모든 API에 공통으로 필요한 API key header다.
        request.setValue(configuration.apiKey, forHTTPHeaderField: "SeSACKey")

        if router.requiresAuthentication {
            guard let accessToken = authManager.tokens?.accessToken else {
                throw NetworkError.missingAuthenticationToken
            }

            request.setValue(accessToken, forHTTPHeaderField: "Authorization")
        }

        // endpoint별로 추가 header가 필요해지면 Router에서만 정의하고 여기서 일괄 반영한다.
        router.headers.forEach { key, value in
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let multipartFormData = router.multipartFormData {
            let boundary = "Boundary-\(UUID().uuidString)"
            request.setValue(
                "multipart/form-data; boundary=\(boundary)",
                forHTTPHeaderField: "Content-Type"
            )
            request.httpBody = multipartFormData.encoded(boundary: boundary)
        } else if let body = router.body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encode(body)
        }

        return request
    }

    func makeURL(path: String, queryItems: [URLQueryItem]) -> URL? {
        // URLComponents를 사용하면 path와 query를 안전하게 조립할 수 있다.
        guard var components = URLComponents(url: configuration.baseURL, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let routePath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        // baseURL이 trailing slash를 포함해도 path가 중복 슬래시로 깨지지 않게 정규화한다.
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
            // Encodable existential은 바로 encode할 수 없어서 AnyEncodable로 감싸 타입을 지운다.
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
            // 실패 응답도 JSON message를 내려줄 수 있으므로, 가능하면 같이 파싱해서 보존한다.
            let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data)
            throw NetworkError.statusCode(httpResponse.statusCode, message: errorResponse?.message, data: data)
        }
    }

    func refreshTokens() async throws {
        guard let currentTokens = authManager.tokens else {
            throw NetworkError.missingAuthenticationToken
        }

        let response: RefreshTokenResponse = try await request(AuthRouter.refresh(currentTokens))
        try authManager.authenticate(with: response.tokens)
    }

    func signOutIfRefreshExpired(with error: Error) throws {
        guard case let NetworkError.statusCode(statusCode, _, _) = error,
              statusCode == 401 || statusCode == 418 else {
            return
        }

        try authManager.signOut()
    }

    func perform(request: URLRequest) async throws -> Data {
        do {
            // URLSession은 Data와 URLResponse를 함께 반환하므로, HTTP status 검증은 별도로 해야 한다.
            let (data, response) = try await session.data(for: request)
            #if DEBUG
            // 비-2xx 응답은 원인 추적을 위해 statusCode와 본문을 콘솔에 남긴다. 정식 배포 전에 제거할 수 있다.
            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                let urlString = request.url?.absoluteString ?? "?"
                let bodyText = String(data: data, encoding: .utf8) ?? "<non-utf8 \(data.count) bytes>"
                print("[NetworkManager] \(httpResponse.statusCode) \(request.httpMethod ?? "?") \(urlString)")
                print("[NetworkManager] response body: \(bodyText)")
            }
            #endif
            try validate(response: response, data: data)
            return data
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.requestFailed(error)
        }
    }
}

// 서로 다른 Request DTO를 Encodable 하나의 값처럼 다루기 위한 작은 type eraser다.
private struct AnyEncodable: Encodable {
    private let encodeValue: (Encoder) throws -> Void

    init(_ value: Encodable) {
        encodeValue = value.encode
    }

    func encode(to encoder: Encoder) throws {
        try encodeValue(encoder)
    }
}
