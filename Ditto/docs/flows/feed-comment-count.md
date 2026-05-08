# 피드 댓글 갯수 자체 카운팅

## 한 줄 요약
이 기능은 서버 PostSummary에 commentCount 필드가 없는 한계를 detail 응답의 `comments.count` 로 자체 보정해 피드 카드에 댓글 갯수를 표시한다.

## 동작 흐름 (구어체)
피드 탭에 들어오면 MainViewModel이 첫 페이지 글들을 받아오면서 각 카드의 commentCount는 일단 0으로 채워진다. 카드가 LazyVStack에 lazy하게 mount되는데, 카드 `.onAppear` 가 발화하는 순간 `viewModel.prefetchCommentCount(forPostId:)` 가 호출된다.

ViewModel은 내부에 `commentCountFetchedPostIds: Set<String>` 캐시를 두고, 이미 한 번 fetch한 글은 즉시 빠져나오게 해서 같은 글을 반복 호출해도 N+1만 한 번 일어나도록 한다. fetch는 PostRouter의 `detail(postId:)` 를 호출해 `PostResponseDTO.comments` 배열을 받아오고, `comments.count` 를 그 글의 `activityPosts[i].commentCount` 에 직접 적어 준다. UI 쪽은 `MainActivityPost.commentCount` 가 var이므로 SwiftUI가 자동으로 카드를 리렌더해서 숫자가 올라간다. 실패하면 캐시 flag를 풀어주기만 해서, 다음 카드 onAppear에서 자동 재시도되도록 했다.

실시간 반영은 PostDetail 화면을 거쳐 들어온다. 사용자가 PostDetail에서 댓글을 작성/삭제/수정하면 PostCommentViewModel.didMutate 콜백이 PostDetailViewModel.load 를 다시 호출해 `viewModel.post.comments` 를 갱신하는데, PostDetailView가 그 변화를 `.onChange(of: viewModel.post?.comments.count)` 로 감지해 부모(MainView)에 주입된 `onCommentCountChange` 콜백을 호출한다. MainView는 그 콜백 안에서 `viewModel.updateCommentCount(forPostId:count:)` 를 호출해 피드 카드의 카운트를 즉시 동기화한다. 즉 PostDetail에서 댓글 한 줄 추가하고 뒤로 가면 피드 카드 숫자가 이미 올라가 있다.

## 왜 이렇게 짰는지
서버가 PostSummary에 commentCount를 안 내려 주는데 추가도 안 한다고 해서, 클라이언트가 자체 카운팅하는 길밖에 없었다. 가장 가벼운 방법은 detail에 이미 들어 있는 `comments` 배열의 길이를 쓰는 것이었다. detail 1회 호출이 카드당 1회이므로 5건짜리 첫 페이지면 detail 5번이 한 번 더 추가로 일어난다. 서버 보강 시 mapper에서 한 줄로 빼낼 수 있게 컨테이너(`activityPosts[i].commentCount`)는 그대로 두고 갱신 경로만 추가하는 식으로 설계했다.

캐시는 ViewModel의 `commentCountFetchedPostIds` 집합 하나로 관리한다. 카드가 onAppear할 때마다 detail을 다시 부르면 LazyVStack이 view를 unmount/remount할 때 비용이 폭주할 수 있어, "한 번 성공한 글은 그냥 skip" 정책을 적용했다.

실시간 반영은 굳이 NotificationCenter나 Pub/Sub 같은 글로벌 채널 없이, PostDetailView에 callback 두 개를 주입해 navigation 경계에서만 mainViewModel을 직접 건드리도록 했다. 같은 패턴으로 `onPostDeleted` 도 추가해 포스트 삭제 시 피드 리스트에서 제거 + navigationPath pop도 한꺼번에 처리한다.

## 시행착오
- 처음엔 첫 페이지 5개에 대해 백그라운드 task에서 병렬 detail fetch를 일괄 돌리는 방식도 생각했지만, "보이는 카드 위주로 fetch" 가 트래픽이 더 자연스럽고, 무한 스크롤로 새 페이지가 들어와도 별도 트리거 없이 onAppear가 자동으로 처리해 준다는 장점이 커서 onAppear 방식으로 갔다.
- realtime 반영을 NotificationCenter로 풀까 했는데, 결국 MainView가 PostDetail을 navigationDestination에서 직접 만드는 구조라 callback 주입이 가장 결합도가 낮았다.

## 핵심 파일
- `Ditto/Features/Main/MainViewModel.swift` — `commentCountFetchedPostIds` 캐시, `prefetchCommentCount(forPostId:)`, `refreshCommentCount(forPostId:)`, `updateCommentCount(forPostId:count:)`, `removeActivityPost(postId:)`. 모두 같은 `activityPosts` 배열을 갱신하는 작은 메서드.
- `Ditto/Features/Main/MainViewData.swift` — `MainActivityPost.commentCount` 를 var로 변경 (SwiftUI 리렌더용).
- `Ditto/Features/Feed/FeedView.swift` — 카드 `.onAppear` 에서 prefetch 호출 (무한 스크롤 trigger와 동일 위치).
- `Ditto/Features/Post/PostDetailView.swift` — `onCommentCountChange` / `onPostDeleted` 콜백, 본인 글 trash 버튼 + alert.
- `Ditto/Features/Main/MainView.swift` — PostDetailView destination에서 두 콜백을 주입.
