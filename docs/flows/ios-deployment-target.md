# iOS Deployment Target 전략

## 한 줄 요약
이 기능은 온디바이스 LLM(Foundation Models)을 iOS 26+ 유저에게만 켜고, 그 외 유저에게는 통계 fallback으로 자연스럽게 떨어뜨리면서 deployment target을 iOS 17까지 낮춰 설치 가능한 사용자 폭을 최대한 확보한다.

## 동작 흐름 (구어체)
"리뷰 화면이 열리면 ViewModel이 `ReviewSummarizer.summarize()`를 호출하는데, 이 안에서 먼저 `if #available(iOS 26, *)`로 OS 버전을 체크해요. iOS 26 이상이면 Foundation Models의 `SystemLanguageModel.default`로 온디바이스 LLM에 후기 30개를 넘겨서 한국어 1~2문장 요약을 받고, 그 결과를 `source = .foundationModels`로 감싸 반환합니다. 만약 iOS 25 이하거나, iOS 26이어도 모델이 안 준비됐거나 LLM 호출 자체가 실패하면 곧장 2단인 통계 템플릿으로 빠져서 평균 별점 + 긍정/중립/부정 비율 한 줄을 만들고 `source = .statsTemplate`으로 반환해요. 호출하는 쪽 ViewModel은 `ReviewSummary` 타입만 받아쓰기 때문에 어느 경로를 탔는지 알 필요가 없고, UI 쪽에서 source enum 보고 모드 칩만 다르게 보여주면 끝입니다."

## 왜 이렇게 짰는지
- **deployment target을 26에 묶는 게 아까웠다.** Foundation Models는 분명 매력적인 기술이지만, 2026년 5월 시점에도 iOS 26 보급률이 충분치 않아서 그 한 기능 때문에 앱 전체를 신버전 유저에게만 노출하는 건 손해라고 판단했다.
- **분기를 Summarizer 내부에 가뒀다.** 호출처에서 OS 분기를 알게 되면 ViewModel·UI 코드가 OS 버전에 오염된다. 입력(리뷰 배열) → 출력(`ReviewSummary`) 계약은 그대로 두고, 어떤 경로로 만들어졌는지는 `source` enum에만 흘려보내서 호출처는 무수정으로 둘 수 있었다.
- **2단 fallback이 이미 깔려 있었다.** Summarizer 자체가 LLM 실패 시 통계 템플릿으로 떨어지게 설계돼 있었기 때문에, OS 분기 가드는 그냥 그 fallback 분기에 한 줄 더 얹는 형태로 자연스럽게 들어갔다.

## 시행착오
- 처음엔 deployment target만 17로 내리면 될 줄 알았는데, `import FoundationModels`와 `SystemLanguageModel.default` 호출이 가드 없이 노출돼 있어서 컴파일이 안 깨질지 검증이 필요했다. SDK는 iOS 26으로 빌드하니 framework는 weak link로 잡히지만, 호출부 자체는 `@available(iOS 26, *)`로 명시적으로 가드해줘야 안전했다.
- struct 전체를 `@available(iOS 26, *)`로 묶을까 고민했는데, 그러면 통계 fallback도 같이 신버전 전용이 돼버려서 본말이 전도된다. 함수 단위로만 가드를 붙이는 게 맞았다.

## 핵심 파일
- `Ditto/Core/NLP/ReviewSummarizer.swift` — LLM 호출과 통계 템플릿이 한 struct에 공존. `summarize()` 안에서 `if #available(iOS 26, *)` 분기, `summarizeWithFoundationModels`에 `@available(iOS 26, *)` 부착.
- `Ditto/Features/Main/ActivityDetailViewModel.swift` — Summarizer를 호출하는 ViewModel. OS 분기는 모름.
- `Ditto/Features/Main/ActivityDetailReviewComponents.swift` — `ReviewSummary.Source` enum으로 UI에 모드 칩만 다르게 표시.
- `Ditto.xcodeproj/project.pbxproj` — `IPHONEOS_DEPLOYMENT_TARGET` 26.0 → 17.0.
