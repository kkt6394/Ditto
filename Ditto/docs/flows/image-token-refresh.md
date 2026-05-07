# 이미지 GET 토큰 자동 갱신 흐름

## 한 줄 요약
이 변경은 인증이 필요한 이미지 GET이 액세스 토큰 만료(서버 419) 때문에 들쭉날쭉하게 폴백 이미지로 떨어지던 문제를 NetworkManager의 토큰 갱신 흐름에 끌고 들어와서 해결한다.

## 동작 흐름 (구어체)

먼저 어떤 증상이었냐면, 프로필 탭에 들어가면 어떤 때는 사용자 사진이 잘 나오고 어떤 때는 액티비티 카드용 폴백 이미지가 나오는 게 반복됐다. 원인을 따라가 보니 `RemoteImageLoader.load(request:)`가 `URLSession.shared.data(for:)`를 직접 호출해서 이미지 GET을 처리하고 있더라. `NetworkManager`는 419(토큰 만료)를 받으면 `refreshTokens()` 후 자동 재시도하는 보호망을 가지고 있는데, 이미지 로더는 그 흐름을 안 타고 있어서 토큰이 막 만료된 타이밍에 진입하면 곧장 실패하고 폴백으로 떨어졌다. 게다가 한 번 실패한 상태로 들어가면 `SearchRemoteImage`의 `task(id:)`가 같은 URL이라 재발화도 안 해서 풀-투-리프레시 전엔 회복이 안 됐다.

그래서 이미지 GET을 NetworkManager 안으로 끌어들였다. `AuthenticatedImageLoading`이라는 작은 프로토콜을 새로 만들고, NetworkManager가 이걸 conform해서 `loadImage(_ request:, pointSize:)`를 제공한다. 이 메서드는 매 시도 직전에 `Authorization` 헤더를 현재 토큰으로 덮어쓰고, 419가 떨어지면 `refreshTokens()`를 부른 다음 새 토큰으로 한 번 더 재시도한다. 디코딩은 기존 `RemoteImageLoader.downsample`을 그대로 호출해서 메모리 다운샘플링 효과를 똑같이 유지했다.

뷰 쪽은 SwiftUI Environment value로 로더를 주입받게 했다. 진입점인 `ContentView`에서 `AuthManager`로 `NetworkManager` 인스턴스를 한 번 만들어 `\.imageLoader` 환경값에 박고, `SearchRemoteImage`는 `@Environment(\.imageLoader)`로 받아서 호출한다. 환경 주입이 없는 컨텍스트(프리뷰 등)에서는 nil이 되니까 그때만 기존 `RemoteImageLoader.load`로 폴백한다. 이렇게 하면 호출자가 `ActivityFormatting.makeImageRequest`로 만들어둔 옛 토큰이 박힌 URLRequest여도, 이미지 로더가 매 시도마다 헤더를 덮어써버려서 무력화된다 — 호출부 시그니처를 안 건드려도 갱신 흐름이 살아남는다.

## 왜 이렇게 짰는지

- **NetworkManager 안으로 끌고 온 이유**: 토큰 보관(`AuthManager`), refresh 직렬화(`TokenRefreshCoordinator`), 만료 사인아웃(`signOutIfRefreshExpired`)이 이미 NetworkManager에 다 모여 있어서 이미지 GET만 따로 같은 보호망을 새로 짜는 건 중복이다. extension으로 `loadImage`만 얹으면 기존 자산을 재활용할 수 있다.
- **별도 프로토콜로 추상화한 이유**: `NetworkManaging`은 `APIRouter` 기반의 추상화고, 이미지 GET은 `URLRequest`를 직접 받는 결이 다른 호출이다. 같은 프로토콜에 섞기보다 `AuthenticatedImageLoading`을 분리해 결합도를 낮추고, 테스트 시에도 mock을 따로 만들기 쉽게 했다.
- **Environment value로 주입한 이유**: `SearchRemoteImage`는 여러 화면에서 쓰이는 공용 뷰라서 호출부마다 로더를 prop으로 넘기면 호출부 시그니처가 다 깨진다. 환경값으로 한 번만 박아두면 뷰 트리 전체에서 받아 쓸 수 있어 변경 범위가 작아진다.
- **`ActivityFormatting.makeImageRequest`를 안 건드린 이유**: 거기 박힌 옛 토큰 헤더는 NetworkManager가 매 시도 직전에 덮어써버리니 동작에 영향이 없다. 호출부 다수(15+ 파일)를 같이 손대지 않아도 돼서 PR 단위가 작아진다.

## 시행착오

처음엔 `RemoteImageLoader.load`에 직접 419 처리/재시도를 넣을까 생각했는데, 그러면 `RemoteImageLoader`가 `AuthManaging`/refresh 흐름까지 알아야 해서 정적 enum의 결을 깨게 된다. 그래서 `RemoteImageLoader`는 데이터 다운샘플링 전용 유틸로 두고, 인증/재시도 책임은 NetworkManager 쪽으로 넘기는 분리 구조로 갔다.

## 핵심 파일

- `Ditto/Core/Network/RemoteImageLoader.swift` — `AuthenticatedImageLoading` 프로토콜과 `EnvironmentValues.imageLoader` 키 정의
- `Ditto/Core/Network/NetworkManager.swift` — `loadImage` 구현. 매 시도 직전 `Authorization`/`SeSACKey` 덮어쓰기 + 419 시 `refreshTokens()` 후 1회 재시도
- `Ditto/Features/Search/SearchActivityComponents.swift` — `SearchRemoteImage`가 `@Environment(\.imageLoader)`로 주입 받아 호출, 주입이 없을 때만 기존 로더로 폴백
- `Ditto/ContentView.swift` — `AuthManager`로 `NetworkManager`를 한 번 만들어 `\.imageLoader` 환경값에 주입

## Step 2 (완료)

`RemoteImageLoader.load`를 직접 호출하던 16곳을 모두 같은 환경 로더 패턴으로 옮겼다. 이제 앱 전반의 인증 이미지 GET이 토큰 갱신 흐름을 탄다. 환경 주입이 없는 컨텍스트(프리뷰 등)는 기존 단순 로더 폴백을 그대로 둬서 호환성 유지.

대상: `PostDetail`(상세 이미지/프로필 2종, 댓글 프로필), `Likes`(카드 워밍업, 줌 오버레이), `Main`(배너/포스트 카드/NEW 액티비티/디테일 헤더), 미디어 뷰어(`ActivityPostMediaViewer`/`ChatRoomBubble`/`ChatRoomMediaViewer`), 리뷰(`ActivityDetailReviewComponents`의 프로필·썸네일 2종, `ReviewComposeView`의 첨부 썸네일), `VideoFeedPlayerCard`의 비디오 썸네일.
