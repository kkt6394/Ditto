//
//  SeSACWebView.swift
//  Ditto
//
//  Created by Codex on 5/2/26.
//

import SwiftUI
import WebKit

// 메인 배너 payload(WEBVIEW)로 진입하는 웹뷰.
// 명세상 SeSACKey 헤더와 click_attendance_button / complete_attendance JS 브릿지가 필수다.
struct SeSACWebView: View {
    let url: URL
    let authManager: any AuthManaging
    let configuration: AppConfiguration

    @Environment(\.dismiss) private var dismiss
    @State private var attendanceCount: Int?
    @State private var isLoadingPage = true

    var body: some View {
        ZStack {
            SeSACWebViewContainer(
                url: url,
                apiKey: configuration.apiKey,
                accessToken: authManager.tokens?.accessToken,
                onAttendanceCompleted: { count in
                    attendanceCount = count
                },
                onPageLoadStateChanged: { loading in
                    isLoadingPage = loading
                }
            )
            .ignoresSafeArea(edges: .bottom)

            if isLoadingPage {
                ProgressView()
            }

            VStack {
                HStack {
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
                    .padding(.top, 14)
                    .padding(.trailing, 14)
                }
                Spacer()
            }
        }
        .alert(
            "출석 완료",
            isPresented: Binding(
                get: { attendanceCount != nil },
                set: { if !$0 { attendanceCount = nil } }
            )
        ) {
            Button("확인") {
                attendanceCount = nil
                dismiss()
            }
        } message: {
            if let attendanceCount {
                Text("\(attendanceCount)번째 출석이 완료되었습니다.")
            }
        }
    }
}

private struct SeSACWebViewContainer: UIViewRepresentable {
    let url: URL
    let apiKey: String
    let accessToken: String?
    let onAttendanceCompleted: (Int) -> Void
    let onPageLoadStateChanged: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            accessToken: accessToken,
            onAttendanceCompleted: onAttendanceCompleted,
            onPageLoadStateChanged: onPageLoadStateChanged
        )
    }

    func makeUIView(context: Context) -> WKWebView {
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "click_attendance_button")
        controller.add(context.coordinator, name: "complete_attendance")

        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView

        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "SeSACKey")
        if let accessToken {
            request.setValue(accessToken, forHTTPHeaderField: "Authorization")
        }
        webView.load(request)

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // 로그인 상태가 바뀌어도 다음 click_attendance_button 시점에 최신 토큰을 쓰도록 갱신
        _ = uiView
        context.coordinator.accessToken = accessToken
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        // 메시지 핸들러는 controller가 strong reference를 잡으므로 화면 종료 시 명시적으로 제거한다.
        _ = coordinator
        let controller = uiView.configuration.userContentController
        controller.removeScriptMessageHandler(forName: "click_attendance_button")
        controller.removeScriptMessageHandler(forName: "complete_attendance")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        var accessToken: String?
        weak var webView: WKWebView?
        private let onAttendanceCompleted: (Int) -> Void
        private let onPageLoadStateChanged: (Bool) -> Void

        init(
            accessToken: String?,
            onAttendanceCompleted: @escaping (Int) -> Void,
            onPageLoadStateChanged: @escaping (Bool) -> Void
        ) {
            self.accessToken = accessToken
            self.onAttendanceCompleted = onAttendanceCompleted
            self.onPageLoadStateChanged = onPageLoadStateChanged
        }

        func userContentController(
            _ controller: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            _ = controller
            switch message.name {
            case "click_attendance_button":
                guard let accessToken else { return }
                // accessToken 문자열에 단일 인용부호가 섞일 가능성이 낮지만 안전하게 escape 한다.
                let escapedToken = accessToken.replacingOccurrences(of: "'", with: "\\'")
                webView?.evaluateJavaScript("requestAttendance('\(escapedToken)')")

            case "complete_attendance":
                if let count = message.body as? Int {
                    onAttendanceCompleted(count)
                } else if let raw = message.body as? String, let count = Int(raw) {
                    onAttendanceCompleted(count)
                }

            default:
                break
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            _ = (webView, navigation)
            onPageLoadStateChanged(true)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            _ = (webView, navigation)
            onPageLoadStateChanged(false)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            _ = (webView, navigation, error)
            onPageLoadStateChanged(false)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            _ = (webView, navigation, error)
            onPageLoadStateChanged(false)
        }
    }
}
