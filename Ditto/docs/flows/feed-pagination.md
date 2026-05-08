# 피드 무한 스크롤 (페이지네이션)

## 한 줄 요약
이 기능은 피드 탭이 cursor 기반 페이지네이션으로 글을 끝까지 이어 받도록 한다.

## 동작 흐름 (구어체)
사용자가 피드 탭에 들어오면 FeedView의 `.task(id: orderBy)` 가 한 번 돌면서 MainViewModel의 `loadActivityPosts(country: nil, category: nil, orderBy:)` 를 호출한다. ViewModel은 PostRouter의 `geolocation` 엔드포인트로 첫 페이지(`limit: 20`)를 가져오고, 응답에 같이 담겨 오는 `nextCursor` 를 `activityPostsNextCursor` 에 저장해둔다. 빈 문자열이 오면 다음 페이지가 없다는 신호라 nil로 처리한다.

피드 카드들은 LazyVStack 안에 ForEach로 그려지는데, 카드마다 `.onAppear` 가 붙어 있다. 사용자가 스크롤하다 마지막 카드(`index == count - 1`)가 화면에 들어오는 순간 곧바로 `loadMoreActivityPosts(...)` 가 호출된다. 이 함수는 cursor가 nil이거나 이미 로드 중이면 즉시 빠져나오고, 그게 아니면 cursor를 query에 실어 같은 endpoint를 다시 때려 다음 페이지를 받아온다. 새로 받아온 카드들은 `activityPosts` 배열 뒤에 append되고, 응답의 `nextCursor` 로 저장된 토큰이 갱신된다. 추가 fetch가 도는 동안에는 리스트 하단에 ProgressView가 잠깐 떴다가 사라진다.

정렬 토글(최신순/인기순)을 누르면 `orderBy` 값이 바뀌고, `task(id: orderBy)` 가 다시 발화하면서 `loadActivityPosts` 가 첫 페이지부터 새로 요청한다. 이때 cursor도 새 응답 기준으로 reset되어 무한 스크롤이 다시 처음부터 시작된다.

글 작성 후에는 MainView의 `reloadActivityPostsAfterCompose()` 가 호출되어 동일하게 첫 페이지부터 다시 가져오므로, 새로 작성한 글이 곧바로 피드 상단에 나타난다 (Feed 탭일 때는 country/category 필터를 nil로 강제해 새 글이 누락되지 않도록 분기해뒀다).

## 왜 이렇게 짰는지
처음에는 `limit: 5` 로 첫 페이지만 받아오고 끝이었다. 그래서 인기순/최신순을 토글하면 동일한 글 5개가 다른 순서로 보이는 게 아니라, 정렬 기준에 따라 서로 다른 글 5개씩이 잡히면서 사용자에게 "갯수가 다르다"는 인상을 줬다.

LazyVStack의 `onAppear` 트리거 + cursor 기반 prefetch 방식을 고른 이유는 ScrollView의 contentOffset/proxy를 직접 다루지 않아도 SwiftUI가 LazyVStack 항목을 lazy하게 mount해 준다는 점을 활용해 추가 코드 없이 자연스럽게 paging이 되기 때문이다. 마지막 카드 onAppear 시점에 prefetch가 시작되므로, 사용자가 끝에 닿기 전에 다음 페이지가 미리 채워질 가능성이 높다.

ViewModel의 `loadMoreActivityPosts` 는 일부러 첫 로드 메시지를 덮지 않는다. 무한 스크롤 중간 fetch가 잠깐 실패해도 사용자가 다시 끝에 닿으면 자동으로 재시도되도록 의도한 것이다.

`activityPostsNextCursor` 는 `String?` 인데 응답의 `nextCursor` 가 빈 문자열이면 nil로 변환해 저장한다. 그렇게 두지 않으면 끝 페이지에 도달했는데도 빈 cursor로 자꾸 호출이 가서 서버에 무의미한 요청을 보낼 수 있다.

## 시행착오
- 첫 시도에서는 `limit` 만 키우는 단순 수정도 후보였지만, 글이 limit를 넘기면 같은 문제가 다시 생기므로 cursor 기반 페이지네이션까지 한 번에 넣는 쪽으로 결정.
- `ForEach(viewModel.activityPosts)` 만으로는 마지막 인덱스를 알 수 없어서, `Array(...).enumerated()` 로 풀어 index를 함께 넘기는 형태로 바꿨다.
- 정렬 토글 시 cursor reset을 깜빡하면 인기순으로 끝까지 스크롤한 뒤 최신순으로 토글하면 첫 페이지만 보이고 무한 스크롤이 안 도는 상황이 생긴다. `loadActivityPosts` 가 첫 페이지를 받을 때마다 cursor를 새 응답으로 덮도록 하여 해결.

## 핵심 파일
- `Ditto/Features/Main/MainViewModel.swift` — `activityPostsNextCursor`, `isLoadingMoreActivityPosts` 상태와 `loadActivityPosts`/`loadMoreActivityPosts` 페어. 첫 페이지 reset과 다음 페이지 append를 분리.
- `Ditto/Features/Feed/FeedView.swift` — LazyVStack 마지막 카드 `.onAppear` 트리거로 prefetch. 하단 ProgressView로 추가 로딩 시각화.
- `Ditto/Core/API/Post/PostModels.swift` — `PostSummaryPaginationResponseDTO.nextCursor` 가 그대로 cursor 토큰으로 쓰인다.
- `Ditto/Core/API/Post/PostRouter.swift` — `geolocation` case에서 `next` 쿼리를 cursor로 전달.
- `Ditto/Features/Main/MainView.swift` — Feed 탭에서 글 작성 후 reload 시 country/category를 nil로 강제하는 분기. 페이지네이션과 함께 새 글이 즉시 노출되도록 한다.
