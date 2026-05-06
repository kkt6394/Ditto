//
//  ChatRoomMediaViewer.swift
//  Ditto
//
//  Created by Codex on 5/2/26.
//

import Foundation
import PDFKit
import SwiftUI
import UIKit

struct ChatMediaFullScreen: View {
    let media: ChatMediaPresentation
    let authManager: any AuthManaging

    var body: some View {
        switch media {
        case .image(let items, let initialIndex):
            ChatImageGalleryFullScreen(items: items, initialIndex: initialIndex)
        case .pdf(let item):
            ChatPDFPreviewSheet(item: item)
        }
    }
}

private struct ChatImageGalleryFullScreen: View {
    @Environment(\.dismiss) private var dismiss
    let items: [ChatMediaItem]
    let initialIndex: Int

    @State private var currentIndex: Int

    init(items: [ChatMediaItem], initialIndex: Int) {
        self.items = items
        // 인덱스가 범위를 벗어나는 비정상 상태 방지.
        let safeIndex = items.indices.contains(initialIndex) ? initialIndex : 0
        self._currentIndex = State(initialValue: safeIndex)
        self.initialIndex = safeIndex
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    // 각 페이지가 자체 로딩/줌을 책임진다. TabView 가 보이는 페이지만 mount 해 메모리 부담을 줄인다.
                    ChatImagePage(item: item)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: items.count > 1 ? .always : .never))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            HStack {
                Spacer()
                if items.count > 1 {
                    // 좌상단에 현재 위치를 표기해 몇 번째 사진을 보고 있는지 명확히 한다.
                    Text("\(currentIndex + 1) / \(items.count)")
                        .font(MainScreenTypography.body)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.45), in: Capsule())
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.45), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

private struct ChatImagePage: View {
    let item: ChatMediaItem

    @State private var image: UIImage?
    @State private var message: String?
    @State private var scale: CGFloat = 1

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = max(1, min(value, 4))
                            }
                    )
            } else {
                VStack(spacing: 12) {
                    if message == nil {
                        ProgressView().tint(.white)
                    }
                    Text(message ?? "사진을 불러오는 중입니다.")
                        .font(MainScreenTypography.body)
                        .foregroundStyle(.white)
                }
                .padding(24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task(id: item.id) {
            await load()
        }
    }

    private func load() async {
        guard let request = item.thumbnailRequest else {
            message = "사진을 불러올 수 없습니다."
            return
        }

        let screenSize = UIScreen.main.bounds.size
        let target = CGSize(width: screenSize.width * 2, height: screenSize.height * 2)

        do {
            let loaded = try await RemoteImageLoader.load(request: request, pointSize: target)
            image = loaded
        } catch {
            message = "사진을 불러올 수 없습니다."
        }
    }
}

private struct ChatPDFPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let item: ChatPDFItem

    @State private var localURL: URL?
    @State private var message: String?

    var body: some View {
        NavigationStack {
            content
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("닫기") { dismiss() }
                    }
                }
                .navigationTitle(item.displayName)
                .navigationBarTitleDisplayMode(.inline)
        }
        .task(id: item.id) {
            await download()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let localURL {
            ChatPDFViewer(url: localURL)
                .ignoresSafeArea(edges: .bottom)
        } else {
            VStack(spacing: 12) {
                if message == nil {
                    ProgressView()
                }
                Text(message ?? "PDF를 불러오는 중입니다.")
                    .font(MainScreenTypography.body)
                    .foregroundStyle(MainScreenPalette.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MainScreenPalette.background)
        }
    }

    private func download() async {
        guard let request = item.downloadRequest else {
            message = "PDF를 불러올 수 없습니다."
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                message = "PDF를 불러올 수 없습니다."
                return
            }

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("pdf")
            try data.write(to: tempURL)
            localURL = tempURL
        } catch {
            message = "PDF를 불러올 수 없습니다."
        }
    }
}

private struct ChatPDFViewer: UIViewRepresentable {
    let url: URL

    func makeUIView(context _: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.document = PDFDocument(url: url)
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context _: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
    }
}
