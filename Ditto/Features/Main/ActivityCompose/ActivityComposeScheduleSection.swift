//
//  ActivityComposeScheduleSection.swift
//  Ditto
//
//  Created by Codex on 5/5/26.
//

import SwiftUI

// 운영 기간(시작일/종료일)과 세부 일정 행을 동적으로 추가·삭제한다.
// 서버 스펙상 duration·description 모두 자유 텍스트라 picker가 아닌 TextField로 둔다.
struct ActivityComposeScheduleSection: View {
    @Bindable var viewModel: ActivityComposeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            periodSection
            detailListSection
        }
    }

    private var periodSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            PostComposeFieldLabel(title: "운영 기간 (선택)")

            HStack(spacing: 12) {
                DatePicker(
                    "",
                    selection: startDateBinding,
                    displayedComponents: .date
                )
                .labelsHidden()

                Text("~")
                    .font(MainScreenTypography.body)
                    .foregroundStyle(MainScreenPalette.textSecondary)

                DatePicker(
                    "",
                    selection: endDateBinding,
                    displayedComponents: .date
                )
                .labelsHidden()
            }
        }
    }

    private var detailListSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                PostComposeFieldLabel(title: "일정 세부 (선택)")
                Spacer()
                Button {
                    viewModel.addScheduleItem()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(MainScreenPalette.primaryBlue)
                }
                .buttonStyle(.plain)
            }

            if viewModel.schedule.isEmpty {
                emptyHint
            } else {
                scheduleRows
            }
        }
    }

    private var emptyHint: some View {
        Text("'+' 버튼으로 일정을 추가할 수 있습니다.")
            .font(MainScreenTypography.bodyCompact)
            .foregroundStyle(MainScreenPalette.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var scheduleRows: some View {
        VStack(spacing: 8) {
            ForEach($viewModel.schedule) { $item in
                scheduleRow(for: $item)
            }
        }
    }

    private func scheduleRow(for item: Binding<ActivityComposeScheduleDraft>) -> some View {
        HStack(spacing: 8) {
            VStack(spacing: 6) {
                TextField("기간 (예: 1시간)", text: item.duration)
                    .textFieldStyle(.roundedBorder)
                TextField("설명 (예: 사파리 투어)", text: item.description)
                    .textFieldStyle(.roundedBorder)
            }

            Button {
                viewModel.removeScheduleItem(item.wrappedValue.id)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
        }
    }

    private var startDateBinding: Binding<Date> {
        Binding(
            get: { viewModel.startDate ?? Date() },
            set: { viewModel.startDate = $0 }
        )
    }

    private var endDateBinding: Binding<Date> {
        Binding(
            get: { viewModel.endDate ?? Date() },
            set: { viewModel.endDate = $0 }
        )
    }
}
