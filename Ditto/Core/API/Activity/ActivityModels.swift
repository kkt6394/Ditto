//
//  ActivityModels.swift
//  Ditto
//
//  Created by Codex on 4/25/26.
//

import Foundation

struct ActivityListQuery: Equatable {
    let country: String?
    let category: String?
    let limit: Int?
    let next: String?
}

struct ActivityPreviewQuery: Equatable {
    let country: String?
    let category: String?
}

struct ActivityKeepListQuery: Equatable {
    let country: String?
    let category: String?
    let next: String?
    let limit: Int?
}

struct ActivityFileUploadRequestDTO: Equatable {
    let files: [MultipartFile]
}

struct ActivityScheduleItemRequestDTO: Encodable, Equatable {
    let duration: String?
    let description: String?
}

struct ActivityCreateRequestDTO: Encodable, Equatable {
    let title: String?
    let country: String?
    let category: String?
    let latitude: Double?
    let longitude: Double?
    let startDate: String?
    let endDate: String?
    let originalPrice: Double?
    let finalPrice: Double?
    let tags: [String]?
    let pointReward: Double?
    let minHeight: Double?
    let minAge: Double?
    let maxParticipants: Double?
    let description: String?
    let isAdvertisement: Bool?
    let schedule: [ActivityScheduleItemRequestDTO]?
    let thumbnails: [String]?

    enum CodingKeys: String, CodingKey {
        case title
        case country
        case category
        case latitude
        case longitude
        case startDate = "start_date"
        case endDate = "end_date"
        case originalPrice = "original_price"
        case finalPrice = "final_price"
        case tags
        case pointReward = "point_reward"
        case minHeight = "min_height"
        case minAge = "min_age"
        case maxParticipants = "max_participants"
        case description
        case isAdvertisement = "is_advertisement"
        case schedule
        case thumbnails
    }
}

typealias ActivityUpdateRequestDTO = ActivityCreateRequestDTO

struct ActivityKeepRequestDTO: Encodable, Equatable {
    let keepStatus: Bool

    enum CodingKeys: String, CodingKey {
        case keepStatus = "keep_status"
    }
}

struct ActivityFileResponseDTO: Decodable, Equatable {
    let thumbnails: [String]?
}

struct ActivityKeepResponseDTO: Decodable, Equatable {
    let keepStatus: Bool
}

struct ActivityPriceDTO: Decodable, Equatable {
    let original: Double
    let final: Double
}

struct ActivityRestrictionsDTO: Decodable, Equatable {
    let minHeight: Double
    let minAge: Double
    let maxParticipants: Double
}

struct ActivityScheduleItemDTO: Decodable, Equatable {
    let duration: String?
    let description: String?
}

struct ActivityReservationTimeDTO: Decodable, Equatable {
    let time: String?
    let isReserved: Bool?
}

struct ActivityReservationItemDTO: Decodable, Equatable {
    let itemName: String
    let times: [ActivityReservationTimeDTO]
}

struct ActivityGeolocationDTO: Decodable, Equatable {
    let longitude: Double
    let latitude: Double
}

struct ActivitySummaryListResponseDTO: Decodable, Equatable {
    let data: [ActivitySummaryResponseDTO]
    let nextCursor: String
}

struct ActivitySummaryArrayResponseDTO: Decodable, Equatable {
    let data: [ActivitySummaryResponseDTO]
}

struct ActivityResponseDTO: Decodable, Equatable {
    let activityId: String
    let title: String?
    let country: String?
    let category: String?
    let thumbnails: [String]
    let geolocation: ActivityGeolocationDTO
    let startDate: String?
    let endDate: String?
    let price: ActivityPriceDTO
    let tags: [String]
    let pointReward: Double?
    let restrictions: ActivityRestrictionsDTO
    let description: String?
    let isAdvertisement: Bool
    let isKeep: Bool
    let keepCount: Int
    let totalOrderCount: Int
    let schedule: [ActivityScheduleItemDTO]?
    let reservationList: [ActivityReservationItemDTO]
    let creator: UserInfoResponseDTO
    let createdAt: String
    let updatedAt: String
}

struct ActivitySummaryResponseDTO: Decodable, Equatable {
    let activityId: String
    let title: String?
    let country: String?
    let category: String?
    let thumbnails: [String]
    let geolocation: ActivityGeolocationDTO
    let price: ActivityPriceDTO
    let tags: [String]
    let pointReward: Double?
    let isAdvertisement: Bool
    let isKeep: Bool
    let keepCount: Int
}

struct ActivitySummaryPostResponseDTO: Decodable, Equatable {
    let id: String
    let title: String?
    let country: String?
    let category: String?
    let thumbnails: [String]
    let geolocation: ActivityGeolocationDTO
    let price: ActivityPriceDTO
    let tags: [String]
    let pointReward: Double?
    let isAdvertisement: Bool
    let isKeep: Bool
    let keepCount: Int
}

struct ActivitySummaryOrderResponseDTO: Decodable, Equatable {
    let id: String
    let title: String?
    let country: String?
    let category: String?
    let thumbnails: [String]
    let geolocation: ActivityGeolocationDTO
    let price: ActivityPriceDTO
    let tags: [String]
    let pointReward: Double?
}
