//
//  PostDetailCommentEditSheet.swift
//  Ditto
//
//  Created by Codex on 5/5/26.
//

import SwiftUI

// 댓글/대댓글 수정용 시트. 본인 댓글에 대해서만 노출한다.
struct PostCommentEditSheet: View {
    @Environment(\.dismiss) private var dismiss

    let target: PostCommentEditTarget
    let isSubmitting: Bool
    let errorMessage: String?
    let onSubmit: (String) -> Void

    @State private var text: String

    init(
        target: PostCommentEditTarget,
        isSubmitting: Bool,
        errorMessage: String?,
        onSubmit: @escaping (String) -> Void
    ) {
        self.target = target
        self.isSubmitting = isSubmitting
        self.errorMessage = errorMessage
        self.onSubmit = onSubmit
        _text = State(initialValue: target.content)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("\(target.creatorNick)님의 댓글 수정")
                    .font(MainScreenTypography.sectionTitle)
                    .foregroundStyle(MainScreenPalette.textPrimary)

                TextField("댓글을 입력해 주세요", text: $text, axis: .vertical)
                    .font(MainScreenTypography.body)
                    .foregroundStyle(MainScreenPalette.textPrimary)
                    .lineLimit(3...8)
                    .padding(12)
                    .background(
                        MainScreenPalette.background,
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(MainScreenPalette.border, lineWidth: 1)
                    )

                if let errorMessage {
                    Text(errorMessage)
                        .font(MainScreenTypography.timestamp)
                        .foregroundStyle(Color(red: 0.72, green: 0.18, blue: 0.14))
                }

                Spacer()
            }
            .padding(20)
            .background(MainScreenPalette.background.ignoresSafeArea())
            .navigationTitle("댓글 수정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSubmit(text)
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Text("저장")
                        }
                    }
                    .disabled(isSubmitting || isContentInvalid)
                }
            }
        }
    }

    private var isContentInvalid: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
