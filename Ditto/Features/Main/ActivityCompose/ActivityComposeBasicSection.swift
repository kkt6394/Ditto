//
//  ActivityComposeBasicSection.swift
//  Ditto
//
//  Created by Codex on 5/5/26.
//

import SwiftUI

// 작성/수정 폼의 첫 섹션. 국가·카테고리·제목·설명만 다룬다.
// 칩 픽커와 제목 필드는 PostCompose 측 컴포넌트를 그대로 재사용해 디자인 일관성을 유지한다.
struct ActivityComposeBasicSection: View {
    @Bindable var viewModel: ActivityComposeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PostComposeChipPicker(
                title: "국가",
                options: viewModel.countryOptions,
                selection: $viewModel.country
            )

            PostComposeChipPicker(
                title: "카테고리",
                options: viewModel.categoryOptions,
                selection: $viewModel.category
            )

            PostComposeTitleField(text: $viewModel.title)

            descriptionField
        }
    }

    // 액티비티용 설명 필드. PostComposeContentField는 포스트용 placeholder가 박혀 있어 별도로 둔다.
    private var descriptionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            PostComposeFieldLabel(title: "소개")

            ZStack(alignment: .topLeading) {
                if viewModel.descriptionText.isEmpty {
                    Text("어떤 액티비티인지, 어떤 분께 추천하는지 자유롭게 적어보세요.")
                        .font(MainScreenTypography.body)
                        .foregroundStyle(PostComposePalette.placeholder)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }

                TextEditor(text: $viewModel.descriptionText)
                    .font(MainScreenTypography.body)
                    .foregroundStyle(PostComposePalette.primaryText)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .frame(minHeight: 140, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(PostComposePalette.inputBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(PostComposePalette.inputBorder, lineWidth: 1)
            )
        }
    }
}
