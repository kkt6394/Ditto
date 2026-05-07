//
//  PendingPaymentValidationStore.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import Foundation

// PG 결제는 끝났는데 서버 검증이 미완료인 결제 정보를 디스크에 보관한다.
// 앱이 강제 종료되거나 메모리 부족으로 죽어도 다음 부팅 때 복구해서 자동 검증을 다시 시도한다.
struct PendingPaymentValidation: Codable, Equatable {
    let orderCode: String
    let impUid: String
    let savedAt: Date
}

protocol PendingPaymentValidationStoring {
    func save(orderCode: String, impUid: String)
    func load() -> PendingPaymentValidation?
    func clear()
}

struct PendingPaymentValidationStore: PendingPaymentValidationStoring {
    private let key = "payment.pendingValidation"
    // 24시간 지나면 서버에서도 거부할 가능성이 커서 폐기 대상으로 본다.
    private let expiry: TimeInterval = 24 * 60 * 60
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let now: () -> Date

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
    }

    func save(orderCode: String, impUid: String) {
        let value = PendingPaymentValidation(orderCode: orderCode, impUid: impUid, savedAt: now())
        guard let data = try? encoder.encode(value) else {
            return
        }
        defaults.set(data, forKey: key)
    }

    func load() -> PendingPaymentValidation? {
        guard let data = defaults.data(forKey: key),
              let value = try? decoder.decode(PendingPaymentValidation.self, from: data) else {
            return nil
        }

        // 만료된 데이터를 들고 있으면 매 부팅마다 헛 호출이 나가니 load 시점에 같이 정리한다.
        if now().timeIntervalSince(value.savedAt) > expiry {
            defaults.removeObject(forKey: key)
            return nil
        }

        return value
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
