//
//  ActivityReportAggregator.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import Foundation

// 활동 리포트 PDF의 표지·요약 페이지에 들어갈 통계.
struct ActivityReportStats: Equatable {
    let totalCount: Int
    let totalSpentKRW: Int
    let firstPaidAt: Date?
    let lastPaidAt: Date?
    let categoryCounts: [CategoryCount]
    let topActivityTitle: String?
    let topActivityPrice: Int?

    struct CategoryCount: Equatable {
        let name: String
        let count: Int
    }
}

enum ActivityReportAggregator {
    static func make(from orders: [OrderReviewResponseDTO]) -> ActivityReportStats {
        // 합계는 정수 KRW로 단순화. 평균은 표기에서 빠지므로 누적값만.
        let totalSpent = orders.reduce(0) { $0 + $1.totalPrice }
        let dates = orders.compactMap { parsePaidAt($0.paidAt) }.sorted()

        let topOrder = orders.max { $0.totalPrice < $1.totalPrice }

        return ActivityReportStats(
            totalCount: orders.count,
            totalSpentKRW: totalSpent,
            firstPaidAt: dates.first,
            lastPaidAt: dates.last,
            categoryCounts: makeCategoryCounts(from: orders),
            topActivityTitle: topOrder?.activity.title,
            topActivityPrice: topOrder?.totalPrice
        )
    }

    // 상위 5개만 그대로, 나머지는 "기타"로 합쳐 카테고리 시각화가 어지럽지 않게 한다.
    private static func makeCategoryCounts(
        from orders: [OrderReviewResponseDTO]
    ) -> [ActivityReportStats.CategoryCount] {
        var bucket: [String: Int] = [:]
        for order in orders {
            let key = order.activity.category ?? "기타"
            bucket[key, default: 0] += 1
        }
        let sorted = bucket
            .map { ActivityReportStats.CategoryCount(name: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }

        guard sorted.count > 5 else { return sorted }
        let top = Array(sorted.prefix(5))
        let rest = sorted.dropFirst(5).reduce(0) { $0 + $1.count }
        return top + [ActivityReportStats.CategoryCount(name: "기타", count: rest)]
    }

    // ISO8601 우선, 실패 시 yyyy-MM-dd. 서버가 둘 다 섞어 보내도 안전하게 받아낸다.
    // ActivityReportScope에서도 같은 파싱 규칙이 필요해 internal로 노출한다.
    static func parsePaidAt(_ raw: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return date }

        let isoNoFractional = ISO8601DateFormatter()
        isoNoFractional.formatOptions = [.withInternetDateTime]
        if let date = isoNoFractional.date(from: raw) { return date }

        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.dateFormat = "yyyy-MM-dd"
        return fallback.date(from: raw)
    }
}
