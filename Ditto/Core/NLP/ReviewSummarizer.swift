//
//  ReviewSummarizer.swift
//  Ditto
//
//  Created by Claude on 5/7/26.
//

import Foundation
import FoundationModels

// 요약 결과. 어떤 단계에서 만들어졌는지 source로 구분해 UI에서 모드 칩을 다르게 보여준다.
struct ReviewSummary: Equatable {
    enum Source: Equatable {
        case foundationModels   // 1단: 온디바이스 LLM
        case statsTemplate      // 2단: 평균 별점 + 긍/중/부 비율 (항상 성공)
    }

    let text: String
    let source: Source
}

// 리뷰 묶음을 1~2줄로 요약한다.
// 2단 fallback: Foundation Models LLM → 통계 템플릿(평균 별점 + 감성 비율).
// 빈도 기반 키워드 나열은 한국어 짧은 리뷰에서 노이즈만 만들어 폐기했다.
struct ReviewSummarizer {
    // LLM에 한 번에 넘길 리뷰 개수 상한.
    private let maxReviewsForPrompt: Int = 30
    // 리뷰 1개당 본문 길이 컷.
    private let maxContentLength: Int = 200

    func summarize(reviews: [(content: String, rating: Int)]) async -> ReviewSummary {
        let cleaned = reviews
            .map { (content: $0.content.trimmingCharacters(in: .whitespacesAndNewlines), rating: $0.rating) }
            .filter { !$0.content.isEmpty }

        guard !cleaned.isEmpty else {
            return ReviewSummary(text: "요약할 리뷰가 없습니다.", source: .statsTemplate)
        }

        // 1단: 온디바이스 LLM (Foundation Models는 iOS 26+에서만 사용 가능)
        if #available(iOS 26, *) {
            if let summary = await summarizeWithFoundationModels(reviews: cleaned.map { $0.content }) {
                return ReviewSummary(text: summary, source: .foundationModels)
            }
        }

        // 2단: 통계 템플릿 — 무조건 성공
        return ReviewSummary(text: statsTemplate(reviews: cleaned), source: .statsTemplate)
    }

    @available(iOS 26, *)
    private func summarizeWithFoundationModels(reviews: [String]) async -> String? {
        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            return nil
        }

        let trimmed = reviews
            .prefix(maxReviewsForPrompt)
            .map { String($0.prefix(maxContentLength)) }

        let instructions = """
        너는 액티비티 후기 요약 도우미다.
        - 출력은 한국어 1~2문장.
        - 톤은 객관적이고 담백하게.
        - 한쪽으로 치우친 의견이라면 그 점을 명시한다.
        - 의견이 갈리면 양쪽 흐름을 모두 적는다.
        - 욕설·고유명사 추측·평점 숫자는 출력에 넣지 않는다.
        """

        let prompt = """
        다음은 한 액티비티에 달린 리뷰들이다. 각 줄이 하나의 리뷰다.
        이 리뷰들의 전체적인 평가 흐름을 1~2문장으로 요약해줘.

        \(trimmed.map { "- \($0)" }.joined(separator: "\n"))
        """

        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(to: prompt)
            let text = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? nil : text
        } catch {
            return nil
        }
    }

    // 2단: LLM이 안 되거나 빈 응답일 때 쓰는 통계 한 줄.
    // 별점만으로 긍/중/부를 분류해 비율을 보여준다 — 빈도 기반 키워드 나열보다 정직하고 노이즈가 없다.
    private func statsTemplate(reviews: [(content: String, rating: Int)]) -> String {
        let total = reviews.count
        let ratings = reviews.map { Double($0.rating) }
        let average = ratings.reduce(0, +) / Double(total)
        let averageText = String(format: "%.1f", average)

        var positive = 0
        var neutral = 0
        var negative = 0
        for review in reviews {
            switch review.rating {
            case 4...: positive += 1
            case 3:    neutral += 1
            default:   negative += 1
            }
        }

        // 합이 100이 되도록 마지막 항목으로 잔차를 흡수한다(반올림 오차 보정).
        let positivePct = Int((Double(positive) / Double(total) * 100.0).rounded())
        let neutralPct  = Int((Double(neutral)  / Double(total) * 100.0).rounded())
        let negativePct = max(0, 100 - positivePct - neutralPct)

        return "평균 별점 \(averageText)점 · 긍정 \(positivePct)% · 중립 \(neutralPct)% · 부정 \(negativePct)%"
    }
}
