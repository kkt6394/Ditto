//
//  ChatRoomNetworkBanner.swift
//  Ditto
//
//  Created by 김기태 on 5/6/26.
//

import SwiftUI

// 채팅방 상단에 끼워넣는 네트워크 상태 배너.
// 단일 BannerState 입력만 받고 자체 색/문구/아이콘을 결정한다.
struct ChatRoomNetworkBanner: View {
    let state: NetworkMonitor.BannerState

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .semibold))

            Text(message)
                .font(MainFont.pretendard(.medium, size: 12))

            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundColor)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var iconName: String {
        switch state {
        case .offline:
            return "wifi.exclamationmark"
        case .reconnecting:
            return "arrow.triangle.2.circlepath"
        case .hidden:
            return ""
        }
    }

    private var message: String {
        switch state {
        case .offline:
            return "네트워크 연결이 끊어졌습니다."
        case .reconnecting:
            return "다시 연결하는 중..."
        case .hidden:
            return ""
        }
    }

    private var backgroundColor: Color {
        switch state {
        case .offline:
            // ChatRoomView 의 에러 텍스트와 동일한 톤으로 일관성 유지.
            return Color(red: 0.72, green: 0.18, blue: 0.14)
        case .reconnecting:
            return MainScreenPalette.textSecondary
        case .hidden:
            return .clear
        }
    }
}
