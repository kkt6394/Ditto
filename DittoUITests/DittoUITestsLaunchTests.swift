//
//  DittoUITestsLaunchTests.swift
//  DittoUITests
//
//  Created by 김기태 on 4/22/26.
//

import XCTest

final class DittoUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // 실패 시 화면 상태를 확인할 수 있도록 시작 화면 스크린샷을 테스트 결과에 첨부한다.
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
