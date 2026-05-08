# Ditto UI 전면 교체 (V5 톤)

## 한 줄 요약
이 작업은 디자인 노드(`UYCxm`/`qKSKQ`/`dqwHP`)에 맞춰 스플래시·홈·피드를 V5 톤으로 갈아끼우면서, 검색 탭을 빼고 그 자리에 피드 탭을 새로 만든 다음, 검색은 홈 TopBar에서 시트로 띄우는 방식으로 전체 외관을 교체한 것이다. 라우팅·네트워크 호출은 그대로 두고 View 표면만 바꿨다.

## 동작 흐름 (구어체)

먼저 앱이 켜지면 새 스플래시(`SplashView`)가 뜹니다. 베이스 회색 위에 흐릿한 컬러 블롭(orb) 세 개가 깔리고, 가운데에 serif italic의 "Ditto" 로고와 가는 디바이더 라인, 영문 tagline, 그리고 0.35초 간격으로 점멸하는 닷 3개로 만든 로딩 인디케이터가 보입니다. 그 사이 백그라운드에서는 기존과 동일하게 `validateTokensIfAuthenticated()`가 토큰을 검사하고, 최소 800ms를 보장한 뒤 `onFinish()`로 메인으로 넘깁니다.

메인 진입 후 하단 탭바(`MainBottomTabBar`)가 Liquid Glass 톤으로 떠 있습니다. `.ultraThinMaterial` 위에 흰색 0.8 fill을 깔고 그 위에 0.6 alpha 흰색 stroke로 보더를 두른 캡슐 모양입니다. 활성 탭은 `#7AB5DC` 캡슐 안에서 흰색 아이콘/라벨로 강조되고, 좋아요 탭 아이콘에는 hero zoom의 destination이 되는 `tabSentinelID` anchor preference를 그대로 발행해서 좋아요 → 상세로 가는 비행 애니메이션이 끊기지 않습니다.

홈 탭 상단(`MainTopBar`)은 좌측 영상 진입 버튼, 가운데 serif italic "Ditto" 로고, 우측 검색 돋보기 버튼으로 구성됩니다. 검색 버튼을 누르면 `MainView`의 `isPresentingSearch` 상태가 켜지면서 `.sheet`로 `SearchView`를 NavigationStack에 감싸 띄웁니다. 알림 버튼은 디자인 노드에도 없고 미구현 상태였어서 제거했습니다.

홈 본문 위쪽에는 카테고리 아이콘 그리드(`CategoryIconGrid`)가 2×5로 배치됩니다. 각 셀은 카테고리별 강조색을 옅게 깐 원 캡슐에 SF Symbol을 얹고, 선택된 셀에는 같은 색의 외곽 링과 라벨 아래 점이 켜집니다. 모델은 `MainCategoryFilter`에 `sfSymbol`/`accentColor` 필드를 도입해서 한 곳에서 카테고리 메타데이터를 관리합니다. 본문 아래쪽으로는 NEW 액티비티 carousel + 메인 배너 + "추천 액티비티" row(`HomeRecommendationRow`)가 차례로 보입니다. 추천 row는 `MainViewModel.loadHomeRecommendations()`가 country/category 필터 없이 `ActivityRouter.new`를 한 번 호출해 채워주는 결과의 앞 두 장을 컴팩트 카드로 보여주고, 탭하면 상세 화면으로 push 됩니다.

피드 탭으로 넘어가면 별도 ViewModel 없이 `MainViewModel.activityPosts`를 그대로 사용합니다. `FeedView`가 진입할 때 `loadActivityPosts(country: nil, category: nil, orderBy: .createdAt)`를 호출하고, 상단 정렬 메뉴에서 "최신순" ↔ "인기순"을 토글하면 `orderBy`가 바뀌어 task가 다시 실행됩니다. 각 포스트는 `FeedPostCard`로 렌더링되며, 작성자 헤더 우측에 푸른 캡슐 "메시지" 버튼이 있습니다. 이 버튼을 탭하면 `chatAction(post)`가 트리거되어 채팅방 생성 → 채팅방 진입 흐름이 그대로 작동합니다. 본문 영역을 탭하면 `detailAction`이 포스트 상세로, 콜라주 안의 미디어를 탭하면 `mediaAction`이 풀스크린 뷰어로 이어집니다. 콜라주는 `ActivityPostImageCollage`를 그대로 재사용했습니다(이번에 internal로 노출했다).

검색 시트(`SearchView`)는 상단에 닫기 버튼과 "검색" 타이틀이 있는 시트 헤더로 시작하고, 검색 입력창 아래에 `SearchCategoryGrid`가 카테고리 카드 6개 + 그 아래 국가 카드 5개를 같은 LazyVGrid 레이아웃으로 보여줍니다. 국가 카드는 카테고리 카드와 같은 카드 톤이지만 우측에 큰 깃발 이모지를 띄우고, 선택된 카드에는 흰색 외곽 stroke가 켜집니다. 국가 선택값은 `SearchViewModel.selectedCountryID`에 저장됩니다. 시트 안에서 카테고리/액티비티를 탭하면 `MainView`가 시트를 dismiss한 뒤 150ms 후 메인 NavigationPath에 push 합니다 — hero zoom과 탭바가 시트 뒤가 아니라 메인 컨텍스트에서 이어지도록 하기 위함입니다.

## 왜 이렇게 짰는지

탭바 자리에 검색 탭을 그대로 두지 않은 건, 검색이 카테고리·국가·거리·추천 등 여러 panel을 모아두는 navigation 깊이가 큰 화면이라 탭 한자리에 두면 다른 탭과의 톤 차이가 컸기 때문입니다. 시트로 띄우면 검색은 모달적인 짧은 흐름으로 바뀌고, 탭바 자리는 SNS 톤의 피드(이미지 콜라주가 메인) 화면이 차지해 디자인 톤이 일관되게 정렬됩니다.

검색 시트의 카테고리/액티비티 push를 시트 dismiss → 메인 path append로 처리한 건, 시트 안 NavigationStack에서 push 하면 hero zoom anchor와 새 Liquid Glass 탭바가 시트 뒤에 가려져 일관성이 깨지기 때문입니다. 150ms 지연은 시트 dismiss 애니메이션이 끝난 직후 push가 자연스럽게 이어지게 하기 위한 조정값입니다.

탭바를 캡슐 floating 톤으로 바꾸면서도 `safeAreaInset(edge: .bottom)`은 그대로 둔 건, 컨텐츠가 탭바 영역 위에서 멈추는 안전한 동작을 우선했기 때문입니다. 완전한 floating(컨텐츠가 탭바 뒤로 흐름)은 `.overlay(alignment: .bottom)`으로 옮기는 별도 조정이 필요한데, 이번 V5 교체 범위에서는 inset 유지가 회귀 위험이 가장 적었습니다.

`MainCategoryFilter` 모델에 `sfSymbol`/`accentColor`를 같이 박아둔 건, 홈의 `CategoryIconGrid`와 향후 검색 시트가 같은 메타데이터로 카테고리를 그릴 수 있도록 하기 위함입니다. SF Symbol과 강조색이 카테고리 자체의 속성이지 그리는 컴포넌트의 속성이 아니라고 봤습니다.

## 시행착오

PR1에서 `MainTab.explore`를 `feed`로 바꾸면서 `MainView.swift`의 `.tag(MainTab.explore.rawValue)` 한 줄만 바꾸면 될 줄 알았는데, `selectTab` 함수 안의 `MainTab(rawValue: item.id) == .explore` 분기가 빌드 에러로 잡혔습니다. enum case를 바꿀 땐 grep `\\.explore`가 잡아주는 패턴 외에도 shorthand 비교 한 자리를 더 봐야 한다는 걸 다시 확인했습니다.

PR5에서 `MainViewModel`에 `loadHomeRecommendations()`를 추가하고 mapper 정적 함수들을 별도 파일로 분리하려 했더니 `resolveCityNames` 안에서 `private(set) var newActivities`의 setter를 못 쓰는 컴파일 에러가 났습니다. `private(set)` setter는 클래스 본체에서만 쓸 수 있어서, mapper 파일에 옮긴 instance 메서드 두 개(`scheduleCityNameResolution`/`resolveCityNames`)는 다시 클래스 본체로 되돌려야 했습니다. 정적 mapper만 별도 파일로 가는 게 가장 깔끔한 분리 단위였습니다.

PR6의 `FeedPostCard`에서 메시지 버튼을 처음에 `Button(action:label:)` 형태로 짰는데 SwiftLint가 multiple_closures_with_trailing_closure 워닝을 잡았습니다. `HStack`에 `.onTapGesture`를 다는 형태로 바꿔서 closure 인자를 하나로 줄였습니다. SwiftUI 표준 코드가 SwiftLint 룰과 자주 부딪히는 케이스라 같은 패턴은 onTapGesture 우회가 깔끔합니다.

PR8 마감에서 `MainView.swift` file_length/type_body_length 워닝을 풀려고 private extension을 별도 파일로 분리하려 했는데, MainView의 `@State private var` 속성들에 다른 파일의 internal extension에서 접근할 수 없는 access level 문제가 걸렸습니다. `@State`를 internal로 격상하면 `private_swiftui_state` 룰을 어기게 되고, 격상하지 않으면 분리가 불가능했습니다. 이번 V5 교체 범위에서는 capsulation을 깨면서까지 분리할 가치가 적다고 판단해서 워닝 누적을 인정하고 마감했습니다(추후 별도 PR에서 helper를 internal로 격상하거나, 액션을 별도 ObservableObject로 빼는 식의 정공법 처리가 필요).

## 핵심 파일

- `Ditto/Features/Common/SplashView.swift` — V5 스플래시(orb 3개, serif italic 로고, 디바이더, 모션 닷)
- `Ditto/Features/Main/MainViewData.swift` — `MainTab.explore` → `feed`, `MainCategoryFilter`에 sfSymbol/accentColor + 4종 추가
- `Ditto/Features/Main/MainViewComponents.swift` — Palette에 glassFill/glassStroke, `MainTopBar` 재배치, `CategoryIconGrid` 신규
- `Ditto/Features/Main/MainPostComponents.swift` — `MainBottomTabBar` Liquid Glass 교체, `ActivityPostImageCollage` internal 노출
- `Ditto/Features/Main/NewActivityComponents.swift` — NEW 액티비티 carousel 계통 분리
- `Ditto/Features/Main/MainViewModel.swift` / `MainViewModelMappers.swift` — `loadHomeRecommendations()` 추가, 정적 mapper 분리
- `Ditto/Features/Main/HomeRecommendationRow.swift` — 추천 액티비티 row
- `Ditto/Features/Main/MainView.swift` — `.feed` 탭에 FeedView 임베드, `.sheet`로 SearchView 띄우기
- `Ditto/Features/Feed/FeedView.swift` / `FeedPostCard.swift` — 새 피드 탭과 포스트 카드
- `Ditto/Features/Search/SearchView.swift` — 시트 헤더로 전환, 카테고리 그리드에 국가 row
- `Ditto/Features/Search/SearchFilterModels.swift` — `SearchCategory`/`SearchCountryFilter` 모델 분리
- `Ditto/Features/Search/SearchViewModel.swift` — `selectedCountryID` 상태 추가
