//
//  ReviewSentimentAnalyzer.swift
//  Ditto
//
//  Created by Claude on 5/7/26.
//

import Foundation
import NaturalLanguage

// 한 리뷰의 감성 분류.
enum ReviewSentiment: String, Equatable {
    case positive
    case neutral
    case negative
}

// 액티비티 단위 감성 분포 요약.
struct ReviewSentimentSummary: Equatable {
    let positive: Int
    let neutral: Int
    let negative: Int

    var total: Int { positive + neutral + negative }

    // UI 뱃지에 표시할 비율(0.0~1.0). total이 0이면 0을 반환한다.
    var positiveRatio: Double {
        guard total > 0 else { return 0 }
        return Double(positive) / Double(total)
    }

    var negativeRatio: Double {
        guard total > 0 else { return 0 }
        return Double(negative) / Double(total)
    }
}

// 리뷰 텍스트의 감성을 평가한다.
// NLTagger의 한국어 sentimentScore 정확도가 들쭉날쭉이라
// 사용자가 직접 매긴 별점(1~5)을 1차 신호로 두고, 텍스트 점수는 보정용으로 결합한다.
struct ReviewSentimentAnalyzer {
    // 별점만으로 분류했을 때의 임계값.
    private let positiveRatingThreshold: Int = 4
    private let negativeRatingThreshold: Int = 2

    // 텍스트 점수가 명확히 한쪽으로 쏠릴 때만 별점 결과를 뒤집는다.
    private let textOverrideMagnitude: Double = 0.5

    func sentiment(for content: String, rating: Int) -> ReviewSentiment {
        let ratingSentiment = sentimentByRating(rating)
        let textScore = textSentimentScore(content)

        // 별점이 중립이거나 텍스트가 강한 반대 신호를 보낼 때만 텍스트 신호를 채택한다.
        guard let textScore else {
            return ratingSentiment
        }

        switch ratingSentiment {
        case .positive where textScore <= -textOverrideMagnitude:
            return .negative
        case .negative where textScore >= textOverrideMagnitude:
            return .positive
        case .neutral:
            if textScore >= textOverrideMagnitude { return .positive }
            if textScore <= -textOverrideMagnitude { return .negative }
            return .neutral
        default:
            return ratingSentiment
        }
    }

    func summary(for reviews: [(content: String, rating: Int)]) -> ReviewSentimentSummary {
        var positive = 0
        var neutral = 0
        var negative = 0

        for review in reviews {
            switch sentiment(for: review.content, rating: review.rating) {
            case .positive: positive += 1
            case .neutral: neutral += 1
            case .negative: negative += 1
            }
        }

        return ReviewSentimentSummary(positive: positive, neutral: neutral, negative: negative)
    }

    private func sentimentByRating(_ rating: Int) -> ReviewSentiment {
        if rating >= positiveRatingThreshold { return .positive }
        if rating <= negativeRatingThreshold { return .negative }
        return .neutral
    }

    // NLTagger.sentimentScore는 -1.0~+1.0의 String?을 반환한다. 한국어는 모델이 학습된 경우만 점수가 채워진다.
    private func textSentimentScore(_ content: String) -> Double? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = trimmed

        let (tag, _) = tagger.tag(at: trimmed.startIndex, unit: .paragraph, scheme: .sentimentScore)
        guard let raw = tag?.rawValue, let score = Double(raw) else {
            return nil
        }
        return score
    }
}
