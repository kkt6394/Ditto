//
//  NetworkMonitor.swift
//  Ditto
//
//  Created by 김기태 on 5/6/26.
//

import Foundation
import Network
import Observation

// 채팅방 상단 배너에 표시할 네트워크/소켓 연결 상태의 단일 소스.
// 시스템 경로(NWPathMonitor)와 채팅 소켓 상태를 합쳐 하나의 BannerState로 노출한다.
// View는 bannerState만 보고 분기하면 깜빡임 없이 일관된 표시를 할 수 있다.
@Observable
@MainActor
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    enum SocketStatus {
        case connected
        case connecting
        case disconnected
    }

    enum BannerState: Equatable {
        case hidden
        case reconnecting
        case offline
    }

    private(set) var isOnline = true
    private(set) var socketStatus: SocketStatus = .disconnected

    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "ditto.network.monitor")

    private init() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            // NWPathMonitor 콜백은 백그라운드 큐에서 호출되므로 메인으로 hop 한다.
            let isReachable = path.status == .satisfied
            Task { @MainActor [weak self] in
                self?.isOnline = isReachable
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }

    func update(socketStatus newValue: SocketStatus) {
        socketStatus = newValue
    }

    var bannerState: BannerState {
        if !isOnline {
            return .offline
        }

        switch socketStatus {
        case .connecting:
            // 첫 진입은 Socket.IO가 .reconnectAttempt 없이 바로 .connect로 이어지므로
            // .connecting 으로 들어오는 경우는 사실상 재연결 시도뿐이다.
            return .reconnecting
        case .connected, .disconnected:
            return .hidden
        }
    }
}
