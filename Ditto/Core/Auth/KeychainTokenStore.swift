//
//  KeychainTokenStore.swift
//  Ditto
//
//  Created by 김기태 on 4/24/26.
//

import Foundation
import Security

// 인증 토큰은 앱 재실행 후에도 유지돼야 하므로 UserDefaults보다 Keychain에 저장하는 편이 안전하다.
struct KeychainTokenStore: TokenStoring {
    private let service: String
    private let account = "auth.tokens"

    init(service: String = Bundle.main.bundleIdentifier ?? "com.ditto.auth") {
        self.service = service
    }

    func loadTokens() throws -> AuthTokens? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data else {
                throw TokenStoreError.decodingFailed
            }

            do {
                return try JSONDecoder().decode(AuthTokens.self, from: data)
            } catch {
                throw TokenStoreError.decodingFailed
            }
        case errSecItemNotFound:
            return nil
        default:
            throw TokenStoreError.unhandledStatus(status)
        }
    }

    func saveTokens(_ tokens: AuthTokens) throws {
        let data: Data

        do {
            data = try JSONEncoder().encode(tokens)
        } catch {
            throw TokenStoreError.encodingFailed
        }

        let status = SecItemAdd(makeNewItem(with: data) as CFDictionary, nil)

        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            let attributesToUpdate = [kSecValueData as String: data] as CFDictionary
            let updateStatus = SecItemUpdate(baseQuery as CFDictionary, attributesToUpdate)

            guard updateStatus == errSecSuccess else {
                throw TokenStoreError.unhandledStatus(updateStatus)
            }
        default:
            throw TokenStoreError.unhandledStatus(status)
        }
    }

    func deleteTokens() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw TokenStoreError.unhandledStatus(status)
        }
    }
}

private extension KeychainTokenStore {
    var baseQuery: [String: Any] {
        [
            // 일반 비밀번호/토큰 류 데이터
            kSecClass as String: kSecClassGenericPassword,
            // 어떤 서비스의 데이터인지 구분하는 이름
            kSecAttrService as String: service,
            // 서비스 안에서 항목 이름이 뭔지
            kSecAttrAccount as String: account
        ]
    }

    func makeNewItem(with data: Data) -> [String: Any] {
        var item = baseQuery
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return item
    }
}
