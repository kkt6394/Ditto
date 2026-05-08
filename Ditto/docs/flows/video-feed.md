# 홈탭 영상 피드 안정화 + 자막

## 한 줄 요약
이 작업은 홈탭의 쇼츠 스타일 영상 피드(`VideoFeedView`)에 (1) 무음 모드에서도 사운드가 들리도록 오디오 세션을 명시적으로 잡고, (2) 백그라운드/인터럽트 시 영상이 자동으로 멈추게 하고, (3) 서버가 내려주는 외부 WebVTT 자막을 직접 파싱해 화면 위에 띄우는 것까지 세 가지를 동시에 다듬은 것이다.

## 동작 흐름 (구어체)

먼저 사용자가 영상 피드 화면(`VideoFeedView`)에 들어오면, 가장 먼저 일어나는 일은 오디오 세션 활성화입니다. `AVAudioSession.sharedInstance()`를 `.playback` 카테고리 + `.moviePlayback` 모드로 잡고 `setActive(true)`를 호출해 둡니다. 이 한 줄 덕분에 기기 무음 스위치가 켜져 있어도 영상 사운드가 정상으로 출력되고, 이어폰이나 블루투스 라우팅도 OS가 영상 재생 표준 동작으로 처리해 줍니다. 화면을 닫을 땐 `.onDisappear`에서 `setActive(false, options: .notifyOthersOnDeactivation)`로 해제해서 다른 앱에 오디오 권한을 돌려줍니다.

그 다음, 사용자가 다른 앱으로 잠깐 빠지거나 컨트롤 센터를 끌어내리는 상황. `VideoFeedView`가 `@Environment(\.scenePhase)`를 구독하고 있다가, `.active`가 아닌 상태(=`.inactive` 또는 `.background`)로 바뀌면 `isPaused = true`로 즉시 전환합니다. 그러면 카드의 `.onChange(of: isPaused)` 핸들러가 `player.pause()`를 호출해 영상이 멈추고, 사용자가 돌아왔을 때 자동 재생되지 않고 일시정지 상태로 대기합니다. 의도치 않게 사운드가 다시 흘러나오는 걸 막기 위함입니다. 사용자가 다시 보고 싶으면 화면 탭으로 명시적으로 재생을 재개합니다.

자막 흐름은 조금 더 깁니다. 영상이 활성화된 카드(`VideoFeedPlayerCard`)는 스트림 URL을 받아오는 `prepareIfNeeded()` 안에서 응답에 함께 들어 있는 `subtitles` 배열도 같이 처리합니다. `isDefault: true`인 자막을 우선, 없으면 첫 번째 자막을 골라 `viewModel.loadSubtitleText(for:)`로 .vtt 파일을 다운로드하고(SeSACKey 헤더 자동 첨부), 그 텍스트를 `WebVTTParser`로 파싱해서 `[WebVTTCue]` 배열을 카드 상태에 보관합니다.

영상 재생이 시작되면 `AVPlayer`에 0.25초 주기 `addPeriodicTimeObserver`를 부착해 현재 재생 시간을 `currentTime` 상태에 계속 흘려보냅니다. 그러면 SwiftUI의 계산 속성 `currentSubtitleText`가 자동으로 재평가되는데, 이 값은 "활성 카드 + 자막 ON + 현재 시간이 큐 범위 안" 세 조건을 모두 만족할 때만 살아 있습니다. 값이 바뀌면 `.onChange(of: currentSubtitleText)`가 부모(`VideoFeedView`)로 콜백을 쏘고, 부모는 그걸 받아 화면 하단에 검정 반투명 캡슐 + 흰 텍스트로 자막을 그립니다. 자막을 카드 안이 아니라 카드 외부 z-order(부모 ZStack)에 그리는 게 핵심입니다.

자막 ON/OFF 토글은 화면 상단 우측에 있는 `captions.bubble` 아이콘 버튼이 담당합니다. 누르면 `isSubtitleEnabled`가 토글되고, OFF가 되면 카드의 `currentSubtitleText`가 즉시 nil이 되어 부모가 자막 오버레이를 안 그립니다.

## 왜 이렇게 짰는지

오디오 세션을 안 잡으면 iOS 기본값이 `.soloAmbient`라서, 무음 스위치가 켜져 있을 때 사운드가 아예 안 납니다. "왜 영상 소리가 안 나요?" 문의로 가장 자주 들어오는 케이스라 명시적으로 `.playback`을 잡았습니다. `.playback`은 영상 플레이어 표준 카테고리이고, `.moviePlayback` 모드는 음성 + 음악이 섞인 멀티미디어에 OS가 가장 자연스러운 라우팅을 자동 적용해 줍니다.

scenePhase를 `.inactive`까지 잡은 건 의도적입니다. `.background`만 잡으면 컨트롤 센터를 끌어내리거나 알림이 떴을 때처럼 잠깐의 인터럽트는 대응하지 못해 사운드가 새어 나갑니다. TikTok·YouTube Shorts도 `.inactive`에서 멈추는 게 표준입니다. 복귀 시 자동 재생을 안 하는 건, 회의 중에 잠깐 다른 거 보다가 돌아왔을 때 갑자기 사운드가 다시 켜지는 게 더 곤란하기 때문입니다. 사용자가 직접 탭해서 재개하는 쪽이 안전합니다.

자막에서 가장 큰 설계 분기점은 "AVMediaSelectionGroup 표준 경로를 쓸 수 있는가"였습니다. iOS는 HLS 마스터 플레이리스트(`master.m3u8`)에 인라인된 자막 트랙은 표준 API로 자동 인식해 주는데, 이번 서버는 `subtitles` 배열에 외부 .vtt URL을 따로 내려줍니다. 즉 인라인이 아니라 별도 파일이라, AVPlayer가 직접 인식할 길이 없습니다. `AVMutableComposition`으로 합성하는 방법도 있지만 .vtt는 timed metadata가 아니라서 합성 트랙으로 직접 못 붙입니다. 그래서 가장 단순하고 정확한 길인 "직접 파싱 + SwiftUI 렌더링"을 골랐습니다.

자막 텍스트를 카드 외부 z-order에 그리는 것도 의도된 선택입니다. `VideoFeedPlayerCard` 파일 위쪽에 이미 코멘트가 달려 있는데, 카드 안에 SwiftUI 자식을 두면 합성 시 AVPlayer view가 위로 올라와 가린다는 메모가 있습니다. 그래서 좋아요 버튼·제목·설명 같은 정보 오버레이도 모두 부모(`VideoFeedView`) ZStack에 그려져 있고, 자막도 같은 패턴을 따랐습니다. 카드는 자막 큐 데이터와 현재 시간만 관리하고, 표시는 부모가 콜백으로 받아서 처리합니다.

`currentSubtitleText`를 카드 안에서 계산 속성으로 둔 건 SwiftUI 반응형 흐름과 잘 맞기 때문입니다. 시간 옵저버 클로저는 `currentTime` 상태만 갱신하고, `isActive`/`isSubtitleEnabled` prop이 바뀌어도 자연스럽게 재계산됩니다. 만약 옵저버 클로저 안에서 직접 분기를 짰다면 prop 변화를 못 따라가는 클로저 캡처 문제가 생겼을 겁니다.

다국어 선택 UI는 이번 스코프에서 의도적으로 제외했습니다. `isDefault` 또는 첫 번째 자막을 자동으로 고르는 단순 로직이라, 향후 메뉴 UI를 추가할 때 큐 데이터 보관 구조나 콜백 흐름은 그대로 재사용할 수 있게 분리해 뒀습니다.

## 시행착오

자막 데이터 처리를 처음 검토했을 때, ViewModel에는 이미 `makeAuthorizedSubtitleRequest(for:)`도 있고 `StreamUrlResponseDTO.subtitles`도 디코딩되고 있어서 "거의 다 됐는데 왜 화면에 안 보이지?" 싶었습니다. 코드를 따라가 보니 `prepareIfNeeded()`에서 `response.streamUrl`만 쓰고 `response.subtitles`는 그대로 버려지고 있었습니다. 데이터 파이프는 다 만들어 놓고 마지막 한 단계(플레이어 부착 + 표시 UI)가 누락된 상태였습니다. 그래서 이번 작업의 핵심은 새 코드를 잔뜩 추가하는 게 아니라 끊어진 마지막 한 칸을 잇는 일이었습니다.

자막 표시 위치를 카드 안에 넣을지 부모에 둘지 한참 고민했습니다. 카드 안에 넣으면 페이지 전환과 자동 동기화가 편하지만, 위에 적은 z-order 이슈로 가려질 위험이 있고, 부모에 두면 활성 카드와 비활성 카드의 콜백 충돌을 신경 써야 했습니다. 결론적으로 "활성 카드만 자막을 부모로 보낸다(`isActive` 가드)"는 단순한 규칙으로 해결했습니다. 비활성 카드는 항상 nil 콜백만 보내므로 부모 입장에선 받아서 그대로 currentSubtitleText에 덮으면 됩니다. 카드 전환 직후 비활성 카드의 nil이 늦게 들어와도 다음 활성 카드의 콜백이 곧 덮어쓰니 깜빡임은 무시할 수준이었습니다.

빌드 직후 SwiftLint가 두 군데 `trailing_closure` 위반을 잡았습니다. `subtitles.first(where: { $0.isDefault })`와 VideoFeedPlayerCard 호출의 `onSubtitleChange:` 라벨 클로저였는데, 전자는 `subtitles.first { $0.isDefault } ?? subtitles.first` 형태로 `??`와 함께 써도 컴파일이 잘 되는 패턴이라 그대로 적용했고, 후자는 마지막 인자라 trailing closure로 변환했습니다. 라벨이 사라지는 게 신경 쓰였지만 직전에 `viewModel:`로 호출이 닫히고 곧바로 클로저가 오는 형태라 가독성 손해가 크지 않았습니다.

## 핵심 파일
- `Ditto/Features/Video/VideoFeedView.swift` — 오디오 세션 활성/비활성, scenePhase 자동 일시정지, 자막 토글 버튼, 자막 오버레이
- `Ditto/Features/Video/VideoFeedPlayerCard.swift` — 자막 큐 로드, 0.25초 시간 옵저버, `currentSubtitleText` 계산 속성, 부모로 콜백
- `Ditto/Features/Video/VideoListViewModel.swift` — `loadSubtitleText(for:)` 메서드 (.vtt 다운로드, SeSACKey 헤더 자동 첨부)
- `Ditto/Features/Video/WebVTTParser.swift` — 외부 .vtt 미니 파서 (시작/끝/텍스트만 추출, 고급 cue 무시)
