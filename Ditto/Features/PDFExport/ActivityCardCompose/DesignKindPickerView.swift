//
//  DesignKindPickerView.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import SwiftUI

// 기본 디자인 객체 추가 시트.
// 21개 DesignKind를 카드 그리드로 보여주고, 다중 액티비티 시 어떤 액티비티의 데이터로 만들지도 선택.
struct DesignKindPickerView: View {
    let snapshots: [ActivityMemorySnapshot]
    let onAdd: (DesignKind, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedOrderIndex: Int = 0

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                if snapshots.count > 1 {
                    activityPicker
                }
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(DesignKind.allCases, id: \.self) { kind in
                            kindCard(kind: kind)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("기본 객체 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }

    private var activityPicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("어느 액티비티의 데이터로 만들까요?")
                .font(MainScreenTypography.body)
                .foregroundStyle(MainScreenPalette.textSecondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<snapshots.count, id: \.self) { index in
                        activityChip(index: index)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 8)
    }

    private func activityChip(index: Int) -> some View {
        let snap = snapshots[index]
        let isSelected = selectedOrderIndex == index
        return Button {
            selectedOrderIndex = index
        } label: {
            Text(snap.activityTitle)
                .font(MainFont.pretendard(.semibold, size: 13))
                .foregroundStyle(isSelected ? Color.white : MainScreenPalette.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isSelected ? MainScreenPalette.primaryBlue : MainScreenPalette.surface,
                    in: Capsule()
                )
                .overlay(Capsule().stroke(MainScreenPalette.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func kindCard(kind: DesignKind) -> some View {
        Button {
            onAdd(kind, selectedOrderIndex)
            dismiss()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: iconName(for: kind))
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(MainScreenPalette.primaryBlue)
                    .frame(height: 28)
                Text(label(for: kind))
                    .font(MainFont.pretendard(.medium, size: 11))
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(
                MainScreenPalette.surface,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(MainScreenPalette.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func label(for kind: DesignKind) -> String {
        Self.labelMap[kind] ?? kind.rawValue
    }

    private func iconName(for kind: DesignKind) -> String {
        Self.iconMap[kind] ?? "questionmark"
    }

    private static let labelMap: [DesignKind: String] = [
        .brand: "Ditto",
        .sub: "activity journal",
        .heroImage: "메인 사진",
        .mainLabel: "활동 이름",
        .dateBox: "DATE",
        .guestsBox: "GUESTS",
        .scheduleBox: "SCHEDULE",
        .totalBox: "TOTAL",
        .quote: "saved this moment",
        .stamp: "DONE 도장",
        .heart: "하트",
        .clip: "종이클립",
        .star1: "✦",
        .star2: "@",
        .hashSign: "#",
        .bottomTitle: "MY ACTIVITY PAGE",
        .underline: "밑줄",
        .arrow1: "↘ 화살표",
        .arrow2: "↗ 화살표",
        .arrow3: "→ 화살표"
    ]

    private static let iconMap: [DesignKind: String] = [
        .brand: "textformat",
        .sub: "textformat",
        .bottomTitle: "textformat",
        .heroImage: "photo",
        .mainLabel: "tag",
        .dateBox: "calendar",
        .guestsBox: "person.2",
        .scheduleBox: "list.bullet",
        .totalBox: "wonsign.circle",
        .quote: "quote.bubble",
        .stamp: "checkmark.seal",
        .heart: "heart.fill",
        .clip: "paperclip",
        .star1: "sparkle",
        .star2: "at",
        .hashSign: "number",
        .underline: "underline",
        .arrow1: "arrow.down.right",
        .arrow2: "arrow.up.right",
        .arrow3: "arrow.right"
    ]
}
