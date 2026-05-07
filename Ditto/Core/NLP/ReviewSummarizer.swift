//
//  ReviewSummarizer.swift
//  Ditto
//
//  Created by Claude on 5/7/26.
//

import Foundation
import FoundationModels
import NaturalLanguage

// 요약 결과. 어떤 단계에서 만들어졌는지 source로 구분해 UI에서 모드 칩을 다르게 보여준다.
struct ReviewSummary: Equatable {
    enum Source: Equatable {
        case foundationModels   // 1단: 온디바이스 LLM
        case phraseFallback     // 2단: N-gram 인접 어절 빈도
        case ratingTemplate     // 3단: 평균 별점 + 키워드 템플릿 (항상 성공)
    }

    let text: String
    let source: Source
}

// 리뷰 묶음을 1~2줄로 요약한다.
// 3단 fallback: Foundation Models LLM → N-gram 구문 빈도 → 평점 템플릿.
// 2·3단 모두 한국어를 어느 정도 견디게 토크나이즈/조사 처리한다.
struct ReviewSummarizer {
    // LLM에 한 번에 넘길 리뷰 개수 상한.
    private let maxReviewsForPrompt: Int = 30
    // 리뷰 1개당 본문 길이 컷.
    private let maxContentLength: Int = 200
    // 2단에서 채택하기 위한 최소 등장 횟수.
    private let phraseMinCount: Int = 2

    func summarize(reviews: [(content: String, rating: Int)]) async -> ReviewSummary {
        let cleaned = reviews
            .map { (content: $0.content.trimmingCharacters(in: .whitespacesAndNewlines), rating: $0.rating) }
            .filter { !$0.content.isEmpty }

        guard !cleaned.isEmpty else {
            return ReviewSummary(text: "요약할 리뷰가 없습니다.", source: .ratingTemplate)
        }

        // 1단: 온디바이스 LLM
        if let summary = await summarizeWithFoundationModels(reviews: cleaned.map { $0.content }) {
            return ReviewSummary(text: summary, source: .foundationModels)
        }

        // 2단: N-gram 인접 어절 빈도
        if let summary = phraseFallback(reviews: cleaned.map { $0.content }) {
            return ReviewSummary(text: summary, source: .phraseFallback)
        }

        // 3단: 평균 별점 템플릿 — 무조건 성공
        return ReviewSummary(text: ratingTemplate(reviews: cleaned), source: .ratingTemplate)
    }

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

    // 2단: 인접 어절 2-gram 빈도. 한국어에서 단일 명사보다 "분위기 좋아요" 같은 구절이 잘 잡힌다.
    // 빈도 phraseMinCount 미만이면 신뢰가 낮다 보고 nil을 반환해 3단으로 넘긴다.
    private func phraseFallback(reviews: [String]) -> String? {
        let tokensPerReview = reviews.map(meaningfulTokens)
        var counts: [String: Int] = [:]

        for tokens in tokensPerReview where tokens.count >= 2 {
            for index in 0..<(tokens.count - 1) {
                let phrase = tokens[index] + " " + tokens[index + 1]
                counts[phrase, default: 0] += 1
            }
        }

        let topPhrases = counts
            .filter { $0.value >= phraseMinCount }
            .sorted { lhs, rhs in
                if lhs.value == rhs.value { return lhs.key < rhs.key }
                return lhs.value > rhs.value
            }
            .prefix(3)
            .map { $0.key }

        guard !topPhrases.isEmpty else {
            return nil
        }

        return "리뷰에서 자주 나온 표현: " + topPhrases.joined(separator: ", ")
    }

    // 3단: 평점 평균 + 단일 명사 키워드 템플릿. 데이터만 있으면 항상 결과가 나온다.
    private func ratingTemplate(reviews: [(content: String, rating: Int)]) -> String {
        let ratings = reviews.map { Double($0.rating) }
        let average = ratings.reduce(0, +) / Double(ratings.count)
        let averageText = String(format: "%.1f", average)

        let allTokens = reviews
            .flatMap { meaningfulTokens(for: $0.content) }
            .filter { $0.count >= 2 }

        var counts: [String: Int] = [:]
        for token in allTokens {
            counts[token, default: 0] += 1
        }

        let topKeywords = counts
            .sorted { lhs, rhs in
                if lhs.value == rhs.value { return lhs.key < rhs.key }
                return lhs.value > rhs.value
            }
            .prefix(5)
            .map { $0.key }

        if topKeywords.isEmpty {
            return "평균 별점 \(averageText)점. 리뷰 \(reviews.count)건이 등록됐습니다."
        }

        return "평균 별점 \(averageText)점. 자주 언급된 키워드: " + topKeywords.joined(separator: ", ")
    }

    // 한국어 어절을 분리하고, 끝부분의 흔한 조사/어미를 제거해 빈도 분석에 쓰기 좋게 정규화한다.
    // 의도적으로 가벼운 휴리스틱이다: 형태소 분석기 없이도 "분위기/는" → "분위기"가 되어 매칭률이 오른다.
    private func meaningfulTokens(for text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text

        var tokens: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let raw = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !raw.isEmpty else { return true }
            // 숫자만/구두점만 들어간 토큰은 버린다.
            guard raw.rangeOfCharacter(from: .letters) != nil else { return true }

            let normalized = stripParticleSuffix(from: raw)
            // 한 글자 + stopword면 버린다. 한 글자라도 명사 같은 의미 단어는 살림.
            guard !shouldDrop(normalized) else { return true }

            tokens.append(normalized)
            return true
        }
        return tokens
    }

    // 흔한 한국어 조사·어미 후보. 길이가 긴 것부터 매칭해야 "에서는" → "에서" → "는" 순으로 안 잘림.
    private static let particleSuffixes: [String] = [
        "에서는", "에서도", "으로는", "으로도", "이라는", "라는",
        "에서", "에게", "께서", "으로", "에는", "에도", "처럼", "마저", "조차", "까지", "부터",
        "은", "는", "이", "가", "을", "를", "의", "도", "만", "와", "과", "로", "께", "야", "여",
        "입니다", "이에요", "예요", "이고", "이며", "이라"
    ]

    private func stripParticleSuffix(from token: String) -> String {
        for suffix in Self.particleSuffixes where token.hasSuffix(suffix) && token.count > suffix.count {
            return String(token.dropLast(suffix.count))
        }
        return token
    }

    // 의미 없는 토큰 컷. stopword에 해당하거나 길이 1짜리 한국어 단음절은 거른다.
    private func shouldDrop(_ token: String) -> Bool {
        if token.count < 2 { return true }
        return Self.stopwords.contains(token)
    }

    private static let stopwords: Set<String> = [
        "정말", "진짜", "완전", "너무", "그냥", "조금", "약간", "매우", "대박",
        "그리고", "그래서", "그런데", "그래도", "하지만", "이건", "저건", "그건",
        "여기", "저기", "거기", "이거", "저거", "그거", "이번", "다음", "이런", "저런", "그런",
        "있어요", "있어", "있다", "없어요", "없어", "없다",
        "해요", "했어요", "했다", "하고", "하는", "하면", "한다",
        "같아요", "같다", "같은", "같이", "같습니다",
        "되게", "되어", "됩니다", "됐어요"
    ]
}
