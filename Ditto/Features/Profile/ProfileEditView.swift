//
//  ProfileEditView.swift
//  Ditto
//
//  Created by Codex on 5/1/26.
//

import PhotosUI
import SwiftUI

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ProfileViewModel

    @State private var nick: String = ""
    @State private var introduction: String = ""
    @State private var phoneNumber: String = ""
    @State private var pickerSelection: PhotosPickerItem?
    @State private var didPrefill = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    avatarSection
                    fieldSection(title: "닉네임") {
                        TextField("닉네임", text: $nick)
                            .textInputAutocapitalization(.never)
                            .modifier(ProfileEditFieldStyle())
                    }
                    fieldSection(title: "소개") {
                        TextField("자기소개를 입력해 주세요.", text: $introduction, axis: .vertical)
                            .lineLimit(3...6)
                            .modifier(ProfileEditFieldStyle())
                    }
                    fieldSection(title: "전화번호") {
                        TextField("010-0000-0000", text: $phoneNumber)
                            .keyboardType(.phonePad)
                            .modifier(ProfileEditFieldStyle())
                    }

                    if let actionMessage = viewModel.actionMessage {
                        ProfileMessageBanner(message: actionMessage)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(MainScreenPalette.background.ignoresSafeArea())
            .navigationTitle("프로필 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            let success = await viewModel.updateProfile(
                                nick: nick,
                                introduction: introduction,
                                phoneNumber: phoneNumber
                            )
                            if success {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isUpdatingProfile {
                            ProgressView()
                        } else {
                            Text("저장")
                                .font(MainFont.pretendard(.bold, size: 14))
                        }
                    }
                    .disabled(viewModel.isUpdatingProfile || viewModel.isUploadingImage)
                }
            }
            .onAppear { prefillIfNeeded() }
            .onChange(of: pickerSelection) { _, item in
                guard let item else { return }
                Task { await loadAndUpload(item) }
            }
        }
    }

    private var avatarSection: some View {
        HStack(spacing: 16) {
            ZStack {
                ProfileAvatar(imageRequest: viewModel.profileImageRequest, size: 80)
                if viewModel.isUploadingImage {
                    Circle()
                        .fill(Color.black.opacity(0.35))
                        .frame(width: 80, height: 80)
                    ProgressView()
                        .tint(.white)
                }
            }

            PhotosPicker(
                selection: $pickerSelection,
                matching: .images,
                photoLibrary: .shared()
            ) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 14, weight: .semibold))
                    Text("사진 변경")
                        .font(MainFont.pretendard(.bold, size: 13))
                }
                .foregroundStyle(MainScreenPalette.primaryBlue)
                .padding(.horizontal, 14)
                .frame(height: 36)
                .background(
                    Capsule().fill(MainScreenPalette.primaryBlueSoft)
                )
            }
            .disabled(viewModel.isUploadingImage)

            Spacer()
        }
    }

    private func fieldSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(MainFont.pretendard(.semibold, size: 13))
                .foregroundStyle(MainScreenPalette.textSecondary)
            content()
        }
    }

    private func prefillIfNeeded() {
        // Sheet가 다시 떠도 사용자가 입력한 값이 덮어쓰이지 않도록 첫 onAppear에서만 채운다.
        guard !didPrefill, let profile = viewModel.profile else { return }
        nick = profile.nick
        introduction = profile.introduction ?? ""
        phoneNumber = profile.phoneNumber ?? ""
        didPrefill = true
    }

    private func loadAndUpload(_ item: PhotosPickerItem) async {
        defer { pickerSelection = nil }
        guard let raw = try? await item.loadTransferable(type: Data.self) else {
            viewModel.actionMessage = "사진을 불러오지 못했습니다."
            return
        }
        // HEIC 등 비-JPEG 원본은 서버 호환을 위해 JPEG로 재인코딩한다.
        let payload: Data
        if let image = UIImage(data: raw),
           let jpeg = image.jpegData(compressionQuality: 0.8) {
            payload = jpeg
        } else {
            payload = raw
        }
        await viewModel.uploadProfileImage(data: payload)
    }
}

private struct ProfileEditFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(MainScreenTypography.body)
            .foregroundStyle(MainScreenPalette.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(MainScreenPalette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(MainScreenPalette.border, lineWidth: 1)
            )
    }
}
