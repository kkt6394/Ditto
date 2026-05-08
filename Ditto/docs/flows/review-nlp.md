# 리뷰 AI 요약 + 감성 분석

## 한 줄 요약
액티비티 상세 화면 리뷰 섹션 위에 AI 요약 카드와 긍정/중립/부정 막대를 띄운다. 요약은 **2단 fallback** (Foundation Models LLM → 통계 템플릿)으로, 환경이 어떻든 빈 카드가 안 나오게 보장한다.

## 동작 흐름 (구어체)
사용자가 액티비티 상세 화면을 열면 `ActivityDetailViewModel.loadReviews()`가 서버에서 리뷰 목록을 가져온다. 응답이 오면 `reviews` 배열을 먼저 채워서 리스트 UI를 그리고, 곧바로 `scheduleReviewAnalysis()`를 호출한다.

여기서부터 두 갈래로 갈린다.

첫 번째 갈래는 감성 분포 계산이다. 리뷰 하나하나를 `ReviewSentimentAnalyzer`에 돌리는데, 우선 별점(1~5)을 1차 신호로 본다. 4점 이상이면 긍정, 2점 이하면 부정, 3점은 중립으로 두고, `NLTagger(.sentimentScore)`로 텍스트 점수를 따로 뽑아서 점수가 ±0.5 넘게 반대 방향이면 별점 판단을 뒤집는다. 별점은 사용자가 명시적으로 매긴 거라 신뢰도가 높고, NLTagger의 한국어 감성 점수는 변동이 커서 보정용으로만 쓰는 게 안전하다. 이 계산은 동기로 끝나서 막대그래프가 거의 즉시 채워진다.

두 번째 갈래는 AI 요약인데 2단으로 떨어진다.

**1단 (LLM, source=foundationModels)** — `SystemLanguageModel.default.isAvailable`이 true면 `LanguageModelSession`에 "객관적 한국어 1~2문장 요약" 지시를 박고 리뷰들을 한 줄씩 묶어 prompt로 보낸다. 응답이 비어 있지 않으면 그대로 채택. 시뮬레이터·미지원 디바이스에선 isAvailable이 false라 바로 다음 단계로.

**2단 (통계 모드, source=statsTemplate)** — LLM이 안 되거나 빈 응답이면 안전망으로 떨어진다. 별점만으로 긍정(4점+)·중립(3점)·부정(2점-)을 분류해 비율을 내고, 평균 별점과 함께 한 줄로 합친다 → "평균 별점 4.5점 · 긍정 78% · 중립 12% · 부정 10%". 빈도 기반 키워드 나열은 한국어 짧은 리뷰에서 노이즈만 만들어서 폐기했다.

UI 쪽에선 `ReviewSection` 안의 `ReviewInsightCard`가 이 결과를 받아서 그린다. 요약은 카드 본문에 뿌리고(분석 중이면 ProgressView), 감성 분포는 카드 하단에 한 줄 막대(긍정 초록 / 중립 회색 / 부정 빨강)와 범례로 보여준다. source가 LLM이면 칩 없음, 2단이면 "통계 모드" 칩을 작게 띄워 모드를 구분한다.

## 왜 이렇게 짰는지
- **별점을 감성 메인 신호로 둔 이유**: NLTagger의 한국어 감성 점수가 들쭉날쭉해서, 사용자가 직접 매긴 별점이 더 신뢰가 높다. 텍스트 점수는 보정용.
- **Foundation Models를 1단에 둔 이유**: 온디바이스라 비용 0원, 서버 키 노출 X. iOS 26 타겟이라 그냥 쓸 수 있다. 외부 LLM API 붙이면 키 관리·과금·서버 프록시가 산더미라 학습 프로젝트엔 과함.
- **빈도 기반 키워드 나열을 폐기한 이유**: 한국어는 형태소 분석기 없이 어절 토큰화만 해서는 의미 단위가 잘 안 잡힌다. "돼요·샀심요·이것" 같은 입말 어미·오타·지시어가 상위 키워드로 잡혀서 요약이라기보단 노이즈가 됐다. stopword를 아무리 늘려도 끝없이 새 노이즈가 나오기 때문에 접근 자체가 한계.
- **통계 한 줄로 대체한 이유**: 거짓말이 안 된다. 별점은 사용자가 매긴 사실이고 비율은 단순 산수다. LLM이 못 도울 땐 가짜 요약 만들지 말고 객관 수치만 보여주는 게 정직하다.
- **분석을 별도 Task에 넣은 이유**: LLM 응답이 수 초 걸릴 수 있어 메인 await로 두면 리스트 그리기가 막힌다. 리스트 먼저, 요약은 나중에 채워지는 흐름이 자연스럽다.
- **시그니처 기반 중복 방지**: 같은 리뷰 묶음을 다시 분석하지 않게 reviewId 시그니처로 가드한다.

## 시행착오
- 처음엔 `NLTagger(.lexicalClass)`로 단일 명사 빈도만 세는 fallback을 만들었는데, 한국어 명사 태깅이 약해서 카드가 비는 케이스가 있었다. → 인접 어절 2-gram + 평점 키워드 템플릿을 추가해 어떤 환경에서도 결과가 나오게 했다.
- 그런데 N-gram도, 키워드 템플릿도 결국 빈도 기반이라 한계가 같았다. 액티비티 이름("오페라하우스")이 가장 높은 빈도로 뽑혀서 정보량이 0이거나, "돼요·샀심요·이것" 같은 노이즈가 상위에 떴다. stopword·고유명사 stripping 같은 미봉책으로는 끝이 없었다. → 빈도 기반 fallback 자체를 폐기하고, LLM이 안 되는 환경에선 별점·감성 비율 통계 한 줄로 대체했다. 가짜 요약보다 정직한 수치가 사용자에게 더 가치 있다는 결정.

## 핵심 파일
- `Ditto/Ditto/Core/NLP/ReviewSentimentAnalyzer.swift` — 별점+NLTagger 결합 감성 분석기, `ReviewSentimentSummary` 분포 모델
- `Ditto/Ditto/Core/NLP/ReviewSummarizer.swift` — Foundation Models 기반 요약기 + 통계 템플릿 fallback
- `Ditto/Ditto/Features/Main/ActivityDetailViewModel.swift` — `loadReviews()` 끝에서 백그라운드 분석 트리거, 결과 상태 보관
- `Ditto/Ditto/Features/Main/ActivityDetailReviewComponents.swift` — `ReviewInsightCard` + `ReviewSentimentBar`로 카드 UI 구성
- `Ditto/Ditto/Features/Main/ActivityDetailView.swift` — `ReviewSection`에 새 props 연결
