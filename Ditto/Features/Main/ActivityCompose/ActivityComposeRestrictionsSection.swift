//
//  ActivityComposeRestrictionsSection.swift
//  Ditto
//
//  Created by Codex on 5/5/26.
//

import SwiftUI

// 가격·참여 제약·태그·광고 토글을 한 섹션에 모아둔다.
// Double? 필드는 String 입력을 양방향 변환하는 binding helper로 다룬다.
struct ActivityComposeRestrictionsSection: View {
    @Bindable var viewModel: ActivityComposeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            pricingGroup
            restrictionsGroup
            tagsField
            advertisementToggle
        }
    }

    private var pricingGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            PostComposeFieldLabel(title: "가격")
            numericField(placeholder: "정상가 (원)", binding: doubleBinding(\.originalPrice))
            numericField(placeholder: "할인가 (원, 필수)", binding: doubleBinding(\.finalPrice))
            numericField(placeholder: "적립 포인트", binding: doubleBinding(\.pointReward))
        }
    }

    private var restrictionsGroup: some View {
        VStack(alignment: .leading, spacing: 8) {
            PostComposeFieldLabel(title: "참여 제약 (선택)")
            numericField(placeholder: "최소 키 (cm)", binding: doubleBinding(\.minHeight))
            numericField(placeholder: "최소 나이", binding: doubleBinding(\.minAge))
            numericField(placeholder: "최대 인원", binding: doubleBinding(\.maxParticipants))
        }
    }

    private var tagsField: some View {
        VStack(alignment: .leading, spacing: 8) {
            PostComposeFieldLabel(title: "태그 (선택, 콤마 구분)")
            TextField(
                "예: 가족, 초보자, 반려견 동반",
                text: $viewModel.tagsText
            )
            .textFieldStyle(.roundedBorder)
        }
    }

    private var advertisementToggle: some View {
        Toggle("광고/오픈할인 상품으로 등록", isOn: $viewModel.isAdvertisement)
            .font(MainScreenTypography.body)
            .tint(MainScreenPalette.primaryBlue)
    }

    private func numericField(placeholder: String, binding: Binding<String>) -> some View {
        TextField(placeholder, text: binding)
            .keyboardType(.decimalPad)
            .textFieldStyle(.roundedBorder)
    }

    private func doubleBinding(
        _ keyPath: ReferenceWritableKeyPath<ActivityComposeViewModel, Double?>
    ) -> Binding<String> {
        Binding(
            get: {
                guard let value = viewModel[keyPath: keyPath] else { return "" }
                return String(format: "%g", value)
            },
            set: { newValue in
                viewModel[keyPath: keyPath] = Double(newValue)
            }
        )
    }
}
