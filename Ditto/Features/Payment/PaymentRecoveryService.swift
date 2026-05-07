//
//  PaymentRecoveryService.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import Foundation

// 앱 부팅 후 인증이 확인되면 호출되어, 미검증 상태로 남아 있는 PG 결제를 자동으로 다시 검증한다.
// 사용자에게 별도 UI를 띄우지 않고 조용히 처리해 결제는 됐는데 서버에 검증이 안 들어간 상태가
// 영구적으로 남는 시나리오를 막는다.
struct PaymentRecoveryService {
    private let store: any PendingPaymentValidationStoring
    private let networkManagerFactory: () throws -> any NetworkManaging

    init(
        store: any PendingPaymentValidationStoring,
        networkManagerFactory: @escaping () throws -> any NetworkManaging
    ) {
        self.store = store
        self.networkManagerFactory = networkManagerFactory
    }

    func recoverIfNeeded() async {
        guard let pending = store.load() else {
            return
        }

        do {
            let networkManager = try networkManagerFactory()
            try await networkManager.send(
                PaymentRouter.validate(PaymentValidationRequestDTO(impUid: pending.impUid))
            )
            store.clear()
            #if DEBUG
            print("[PaymentRecovery] re-validation succeeded for orderCode=\(pending.orderCode)")
            #endif
        } catch {
            // 4xx는 서버가 재시도해도 결과가 안 바뀐다는 신호라 store에서 비워 무한 호출을 막는다.
            // 그 외(네트워크 단절, 5xx 등)는 다음 부팅 때 다시 시도하도록 store를 유지한다.
            if Self.isPermanentFailure(error) {
                store.clear()
            }

            #if DEBUG
            print("[PaymentRecovery] re-validation failed: \(error)")
            #endif
        }
    }

    private static func isPermanentFailure(_ error: Error) -> Bool {
        guard let networkError = error as? NetworkError else {
            return false
        }

        switch networkError {
        case .statusCode(let code, _, _):
            return (400..<500).contains(code) && code != 419
        default:
            return false
        }
    }
}
