//
//  BannerModels.swift
//  Ditto
//
//  Created by Codex on 4/25/26.
//

import Foundation

struct BannerResponseDTO: Decodable, Equatable {
    let name: String
    let imageUrl: String
    let payload: BannerPayloadDTO
}

struct BannerPayloadDTO: Decodable, Equatable {
    let type: String
    let value: String
}

struct BannerListResponseDTO: Decodable, Equatable {
    let data: [BannerResponseDTO]
}
