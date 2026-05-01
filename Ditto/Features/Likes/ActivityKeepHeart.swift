//
//  ActivityKeepHeart.swift
//  Ditto
//
//  Created by Codex on 5/1/26.
//

import SwiftUI

// 액티비티 좋아요(keep) 토글 버튼.
// KeepStore를 환경에서 받아 isKept 상태를 그리고 토글한다.
// 어두운 카드 사진 위에 얹히는 것을 기본으로 디자인했다.
struct ActivityKeepHeart: View {
    @Environment(KeepStore.self) private var keepStore

    let activityId: String
    var size: CGFloat = 28
    var iconWeight: Font.Weight = .semibold

    private static let likedColor = Color(red: 1.0, green: 0.38, blue: 0.52)

    var body: some View {
        let isKept = keepStore.isKept(activityId)

        Button {
            Task {
                await keepStore.toggleKeep(activityId: activityId)
            }
        } label: {
            Image(systemName: isKept ? "heart.fill" : "heart")
                .font(.system(size: size * 0.52, weight: iconWeight))
                .foregroundStyle(isKept ? Self.likedColor : .white)
                .symbolEffect(.bounce, value: isKept)
                .frame(width: size, height: size)
                .background(.black.opacity(0.18), in: Circle())
                .scaleEffect(isKept ? 1.12 : 1.0)
                .animation(.spring(response: 0.32, dampingFraction: 0.55), value: isKept)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isKept ? "좋아요 취소" : "좋아요")
        .anchorPreference(key: ActivityHeartAnchorKey.self, value: .center) { anchor in
            [activityId: anchor]
        }
    }
}
