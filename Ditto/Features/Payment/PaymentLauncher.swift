//
//  PaymentLauncher.swift
//  Ditto
//
//  Created by Codex on 4/30/26.
//

import iamport_ios
import SwiftUI
import UIKit

// 포트원(아임포트) SDK는 UIViewController 기반이라 SwiftUI에서 사용하려면 Representable로 감싸야 한다.
// fullScreenCover로 띄우는 컨테이너 ViewController가 결제 webview를 직접 호스팅한다.
struct PaymentLauncher: UIViewControllerRepresentable {
    let userCode: String
    let payment: IamportPayment
    let onComplete: (IamportResponse?) -> Void

    func makeUIViewController(context _: Context) -> PaymentLauncherViewController {
        let viewController = PaymentLauncherViewController()
        viewController.userCode = userCode
        viewController.payment = payment
        viewController.onComplete = onComplete
        return viewController
    }

    func updateUIViewController(_: PaymentLauncherViewController, context _: Context) {
        // 결제 호출은 viewDidAppear에서 한 번만 트리거되므로 update에서는 별도 작업이 필요 없다.
    }
}

final class PaymentLauncherViewController: UIViewController {
    fileprivate var userCode: String = ""
    fileprivate var payment: IamportPayment?
    fileprivate var onComplete: ((IamportResponse?) -> Void)?

    private var didStartPayment = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        guard !didStartPayment, let payment else {
            return
        }
        didStartPayment = true

        Iamport.shared.payment(
            viewController: self,
            userCode: userCode,
            payment: payment
        ) { [weak self] response in
            self?.onComplete?(response)
        }
    }
}
