//
//  PaymentModels.swift
//  Ditto
//
//  Created by Codex on 4/25/26.
//

import Foundation

struct PaymentValidationRequestDTO: Encodable, Equatable {
    let impUid: String

    enum CodingKeys: String, CodingKey {
        case impUid = "imp_uid"
    }
}

struct ReceiptOrderResponseDTO: Decodable, Equatable {
    let paymentId: String
    let orderItem: OrderResponseDTO
    let createdAt: String
    let updatedAt: String
}

struct PaymentResponseDTO: Decodable, Equatable {
    let impUid: String
    let merchantUid: String
    let payMethod: String?
    let channel: String?
    let pgProvider: String?
    let embPgProvider: String?
    let pgTid: String?
    let pgId: String?
    let escrow: Bool?
    let applyNum: String?
    let bankCode: String?
    let bankName: String?
    let cardCode: String?
    let cardName: String?
    let cardIssuerCode: String?
    let cardIssuerName: String?
    let cardPublisherCode: String?
    let cardPublisherName: String?
    let cardQuota: Int?
    let cardNumber: String?
    let cardType: Int?
    let vbankCode: String?
    let vbankName: String?
    let vbankNum: String?
    let vbankHolder: String?
    let vbankDate: Int?
    let vbankIssuedAt: Int?
    let name: String?
    let amount: Int
    let currency: String
    let buyerName: String?
    let buyerEmail: String?
    let buyerTel: String?
    let buyerAddr: String?
    let buyerPostcode: String?
    let customData: String?
    let userAgent: String?
    let status: String
    let startedAt: String?
    let paidAt: String
    let receiptUrl: String?
    let createdAt: String?
    let updatedAt: String?
}
