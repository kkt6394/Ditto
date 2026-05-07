//
//  ActivityReportScope.swift
//  Ditto
//
//  Created by 김기태 on 5/7/26.
//

import Foundation

// 활동 리포트의 시점 단위. 전체 / 특정 연도 / 특정 (연, 월).
enum ActivityReportScope: Hashable {
    case all
    case year(Int)
    case month(Int, Int)

    var displayLabel: String {
        switch self {
        case .all:
            return "전체"
        case .year(let year):
            return "\(year)년"
        case .month(let year, let month):
            return "\(year)년 \(month)월"
        }
    }

    var fileSuffix: String {
        switch self {
        case .all:
            return "전체"
        case .year(let year):
            return "\(year)"
        case .month(let year, let month):
            return String(format: "%04d-%02d", year, month)
        }
    }
}

extension ActivityReportScope {
    // 주문 목록을 scope으로 필터링한다.
    static func filter(
        _ orders: [OrderReviewResponseDTO],
        by scope: ActivityReportScope
    ) -> [OrderReviewResponseDTO] {
        switch scope {
        case .all:
            return orders
        case .year(let year):
            return orders.filter {
                guard let date = ActivityReportAggregator.parsePaidAt($0.paidAt) else { return false }
                return Calendar.current.component(.year, from: date) == year
            }
        case .month(let year, let month):
            return orders.filter {
                guard let date = ActivityReportAggregator.parsePaidAt($0.paidAt) else { return false }
                let components = Calendar.current.dateComponents([.year, .month], from: date)
                return components.year == year && components.month == month
            }
        }
    }

    // 주문 paidAt을 훑어 사용 가능한 scope 옵션을 만든다.
    // 항상 .all이 첫 번째, 그 다음 year(내림차순), 그 다음 (year, month)(내림차순).
    static func availableScopes(
        from orders: [OrderReviewResponseDTO]
    ) -> [ActivityReportScope] {
        var years: Set<Int> = []
        var yearMonths: Set<YearMonthKey> = []

        for order in orders {
            guard let date = ActivityReportAggregator.parsePaidAt(order.paidAt) else { continue }
            let components = Calendar.current.dateComponents([.year, .month], from: date)
            if let year = components.year {
                years.insert(year)
                if let month = components.month {
                    yearMonths.insert(YearMonthKey(year: year, month: month))
                }
            }
        }

        let yearScopes = years
            .sorted(by: >)
            .map(ActivityReportScope.year)

        let monthScopes = yearMonths
            .sorted { lhs, rhs in
                if lhs.year != rhs.year { return lhs.year > rhs.year }
                return lhs.month > rhs.month
            }
            .map { ActivityReportScope.month($0.year, $0.month) }

        return [.all] + yearScopes + monthScopes
    }

    private struct YearMonthKey: Hashable {
        let year: Int
        let month: Int
    }
}
