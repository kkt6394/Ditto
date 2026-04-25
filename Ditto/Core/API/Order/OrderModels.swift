//
//  OrderModels.swift
//  Ditto
//
//  Created by Codex on 4/25/26.
//

import Foundation

struct OrderCreateRequestDTO: Encodable, Equatable {
    let activityId: String
    let reservationItemName: String
    let reservationItemTime: String
    let participantCount: Int
    let totalPrice: Int

    enum CodingKeys: String, CodingKey {
        case activityId = "activity_id"
        case reservationItemName = "reservation_item_name"
        case reservationItemTime = "reservation_item_time"
        case participantCount = "participant_count"
        case totalPrice = "total_price"
    }
}

struct OrderCreateResponseDTO: Decodable, Equatable {
    let orderId: String
    let orderCode: String
    let totalPrice: Int
    let createdAt: String
    let updatedAt: String
}

struct OrderReviewSummaryDTO: Decodable, Equatable {
    let id: String
    let rating: Double
}

struct OrderResponseDTO: Decodable, Equatable {
    let orderId: String
    let orderCode: String
    let totalPrice: Int
    let reservationItemName: String
    let reservationItemTime: String
    let participantCount: Int
    let activity: ActivitySummaryOrderResponseDTO
    let paidAt: String
    let createdAt: String
    let updatedAt: String
}

struct OrderReviewResponseDTO: Decodable, Equatable {
    let orderId: String
    let orderCode: String
    let totalPrice: Int
    let review: OrderReviewSummaryDTO?
    let reservationItemName: String
    let reservationItemTime: String
    let participantCount: Int
    let activity: ActivitySummaryOrderResponseDTO
    let paidAt: String
    let createdAt: String
    let updatedAt: String
}

struct OrdersResponseDTO: Decodable, Equatable {
    let data: [OrderReviewResponseDTO]
}
