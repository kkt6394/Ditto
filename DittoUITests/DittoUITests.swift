//
//  DittoUITests.swift
//  DittoUITests
//
//  Created by 김기태 on 4/22/26.
//

import XCTest

final class DittoUITests: XCTestCase {

    override func setUpWithError() throws {
        // UI 테스트는 한 단계가 실패하면 뒤의 검증도 의미가 없어지므로 즉시 중단한다.
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // 테스트별 정리 작업이 필요해지면 앱 데이터 초기화 코드를 이 위치에 둔다.
    }

    @MainActor
    func testExample() throws {
        // XCUIApplication은 실제 앱 프로세스를 실행해 사용자가 보는 화면 기준으로 검증한다.
        let app = XCUIApplication()
        app.launch()
    }

    @MainActor
    func testLaunchPerformance() throws {
        // launch performance는 앱 시작 시간이 과도하게 늘어나는 회귀를 잡기 위한 기본 성능 테스트다.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
