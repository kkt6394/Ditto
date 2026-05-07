# 리뷰 AI 요약 + 감성 분석

## 한 줄 요약
액티비티 상세 화면 리뷰 섹션 위에 AI 요약 카드와 긍정/중립/부정 막대를 띄운다. 요약은 **3단 fallback** (Foundation Models LLM → N-gram 구문 빈도 → 평점 템플릿) 으로, 환경이 어떻든 빈 카드가 안 나오게 보장한다.

## 동작 흐름 (구어체)
사용자가 액티비티 상세 화면을 열면 `ActivityDetailViewModel.loadReviews()`가 서버에서 리뷰 목록을 가져온다. 응답이 오면 `reviews` 배열을 먼저 채워서 리스트 UI를 그리고, 곧바로 `scheduleReviewAnalysis()`를 호출한다.

여기서부터 두 갈래로 갈린다.

첫 번째 갈래는 감성 분포 계산이다. 리뷰 하나하나를 `ReviewSentimentAnalyzer`에 돌리는데, 우선 별점(1~5)을 1차 신호로 본다. 4점 이상이면 긍정, 2점 이하면 부정, 3점은 중립으로 두고, `NLTagger(.sentimentScore)`로 텍스트 점수를 따로 뽑아서 점수가 ±0.5 넘게 반대 방향이면 별점 판단을 뒤집는다. 별점은 사용자가 명시적으로 매긴 거라 신뢰도가 높고, NLTagger의 한국어 감성 점수는 변동이 커서 보정용으로만 쓰는 게 안전하다. 이 계산은 동기로 끝나서 막대그래프가 거의 즉시 채워진다.

두 번째 갈래는 AI 요약인데 3단으로 떨어진다.

**1단 (LLM, source=foundationModels)** — `SystemLanguageModel.default.isAvailable`이 true면 `LanguageModelSession`에 "객관적 한국어 1~2문장 요약" 지시를 박고 리뷰들을 한 줄씩 묶어 prompt로 보낸다. 응답이 비어 있지 않으면 그대로 채택. 시뮬레이터·미지원 디바이스에선 isAvailable이 false라 바로 다음 단계로.

**2단 (구문 모드, source=phraseFallback)** — `NLTokenizer(unit: .word)`로 어절을 분리하고, 끝의 흔한 조사("은/는/이/가/에서/으로/이라는…")를 휴리스틱으로 잘라낸다. 그 다음 인접 2-gram을 만들어 빈도를 센다. 빈도 2 이상으로 잡힌 표현이 하나라도 있으면 상위 3개를 "리뷰에서 자주 나온 표현: A, B, C"로 합쳐서 채택. 한국어는 단일 명사 추출이 약해서 "분위기 좋아요" 같은 두 어절 결합이 의미를 더 잘 잡는다.

**3단 (평점 모드, source=ratingTemplate)** — 2단도 비면 무조건 성공하는 안전망으로 떨어진다. 별점 평균을 계산해 "평균 별점 X.X점"을 만들고, 같은 토크나이저로 1-gram 명사 키워드 상위 5개를 뒤에 이어 붙인다. 키워드도 못 뽑으면 "리뷰 N건이 등록됐습니다"로 마무리.

UI 쪽에선 `ReviewSection` 안의 `ReviewInsightCard`가 이 결과를 받아서 그린다. 요약은 카드 본문에 뿌리고(분석 중이면 ProgressView), 감성 분포는 카드 하단에 한 줄 막대(긍정 초록 / 중립 회색 / 부정 빨강)와 범례로 보여준다. source가 LLM이면 칩 없음, 2단이면 "구문 모드", 3단이면 "평점 모드" 칩을 작게 띄워 모드를 구분한다.

## 왜 이렇게 짰는지
- **별점을 감성 메인 신호로 둔 이유**: NLTagger의 한국어 감성 점수가 들쭉날쭉해서, 사용자가 직접 매긴 별점이 더 신뢰가 높다. 텍스트 점수는 보정용.
- **Foundation Models를 1단에 둔 이유**: 온디바이스라 비용 0원, 서버 키 노출 X. iOS 26 타겟이라 그냥 쓸 수 있다. 외부 LLM API 붙이면 키 관리·과금·서버 프록시가 산더미라 학습 프로젝트엔 과함.
- **2단에서 단일 명사가 아니라 N-gram을 고른 이유**: 처음엔 `NLTagger(.lexicalClass)`로 단일 명사 빈도를 세는 fallback을 짰는데, 한국어는 명사 태깅이 잘 안 잡혀서 카드가 비는 케이스가 있었다. 인접 어절 2-gram은 조사가 붙어 있어도 빈도로 묶이고 의미도 더 풍부해서 더 안정적이다.
- **3단을 굳이 만든 이유**: 2단조차 빈도 2 미만이면 비울 수 있는데, 사용자 입장에선 빈 카드가 가장 짜증난다. 별점 평균은 데이터만 있으면 무조건 나오니 안전망 한 단을 더 둔다.
- **분석을 별도 Task에 넣은 이유**: LLM 응답이 수 초 걸릴 수 있어 메인 await로 두면 리스트 그리기가 막힌다. 리스트 먼저, 요약은 나중에 채워지는 흐름이 자연스럽다.
- **시그니처 기반 중복 방지**: 같은 리뷰 묶음을 다시 분석하지 않게 reviewId 시그니처로 가드한다.

## 시행착오
- 처음엔 `NLTagger(.lexicalClass)`로 단일 명사 빈도만 세는 단순 fallback을 만들었는데, 시뮬레이터(Apple Intelligence 미지원)에서 카드가 "리뷰 키워드를 추출하지 못했습니다."로 떴다. 한국어 명사 태깅이 약해서 빈도가 안 잡힌 게 원인. → 2단 N-gram + 3단 평점 템플릿을 추가해 어떤 환경에서도 빈 카드가 안 뜨게 막았다.

## 핵심 파일
- `Ditto/Ditto/Core/NLP/ReviewSentimentAnalyzer.swift` — 별점+NLTagger 결합 감성 분석기, `ReviewSentimentSummary` 분포 모델
- `Ditto/Ditto/Core/NLP/ReviewSummarizer.swift` — Foundation Models 기반 요약기 + NLTagger 키워드 fallback
- `Ditto/Ditto/Features/Main/ActivityDetailViewModel.swift` — `loadReviews()` 끝에서 백그라운드 분석 트리거, 결과 상태 보관
- `Ditto/Ditto/Features/Main/ActivityDetailReviewComponents.swift` — `ReviewInsightCard` + `ReviewSentimentBar`로 카드 UI 구성
- `Ditto/Ditto/Features/Main/ActivityDetailView.swift` — `ReviewSection`에 새 props 연결
