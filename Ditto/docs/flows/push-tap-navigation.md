# 푸시 탭 → 채팅방 진입

## 한 줄 요약
이 기능은 채팅 푸시 알림을 사용자가 탭했을 때 해당 채팅방으로 곧바로 진입시킨다. 앱이 포어그라운드든, 백그라운드든, 완전히 종료된 상태든 동일하게 동작한다.

## 동작 흐름 (구어체)

서버가 채팅 메시지를 저장하면 FCM으로 푸시를 발송하는데, 페이로드에는 `room_id`(채팅방 식별자)와 `aps.alert.subtitle`(보낸 사람 닉네임)이 같이 실려서 옵니다. 사용자가 그 푸시를 탭하면, iOS가 우리 앱의 `AppDelegate`에 있는 `userNotificationCenter(_:didReceive:)`를 호출해 줍니다. 거기서 페이로드를 파싱해 `room_id`와 `subtitle`을 꺼낸 다음, `PushNavigator`라는 싱글톤 옵저버블 객체에 "이 방으로 진입해 달라"는 요청을 set 합니다.

`MainView`는 처음 떴을 때(.onAppear)와 `PushNavigator.shared.pendingChat`이 변할 때마다 그 pending을 확인하는데, 값이 들어와 있으면 채팅 탭으로 전환한 뒤 `navigationPath`를 `[.chat(roomId, opponentNick)]`으로 통째로 교체합니다. 그러면 NavigationStack이 `ChatRoomView`를 push해서 사용자에게 채팅방을 보여주고, 마지막으로 `PushNavigator.shared.consume()`을 호출해서 같은 진입을 두 번 처리하지 않도록 비웁니다.

앱이 완전히 종료된 상태에서 푸시로 켜진 경우엔 `didReceive`가 호출되지 않고 `didFinishLaunchingWithOptions`의 `launchOptions[.remoteNotification]`에만 페이로드가 들어옵니다. 그래서 같은 `routeChatPush(from:)` 함수를 launchOptions에서도 한 번 호출해, 종료 상태든 백그라운드든 동일한 다리(`PushNavigator`)를 거치도록 통일했습니다.

비로그인 상태에서 푸시 탭이 일어나도 `MainView`가 그 시점엔 mount돼 있지 않아 옵저빙이 동작하지 않습니다. pending은 메모리에 남아 있다가 사용자가 로그인을 마치고 `MainView`가 처음 뜨는 순간 `.onAppear`에서 자연스럽게 소비됩니다. 따로 가드 코드를 추가할 필요 없이 뷰 계층 자체가 가드 역할을 합니다.

## 왜 이렇게 짰는지

`AppDelegate`(콜백 컨텍스트)와 `MainView`(SwiftUI 뷰 계층) 사이에 직접 통신 채널을 두기 어려워서, 가운데에 `@Observable @MainActor` 싱글톤 다리 객체를 한 칸 끼웠습니다. 요청자는 set만, 소비자는 read 후 consume만 하는 단방향 흐름으로 단순화하니, AppDelegate가 NavigationStack에 직접 손대지 않아도 되고 MainView도 어디서 요청이 왔는지 신경 쓸 필요가 없습니다.

이름을 처음에 `PushRouter`로 두었다가, 같은 이름의 API 라우터 enum이 `Core/API/Push/`에 이미 있어서 `stringsdata` 충돌이 났습니다. 푸시로 인한 화면 이동을 다룬다는 의미를 더 정확히 담기 위해 `PushNavigator`로 바꿨습니다.

진입 시점에 상대 닉네임을 어디서 가져올지 두 가지 방법이 있었습니다. 채팅 리스트 캐시에서 `roomId`로 매칭해 찾는 방법(옵션 A)과, 페이로드의 subtitle을 바로 쓰는 방법(옵션 C). 디버그 출력으로 실제 페이로드를 확인해 보니 `aps.alert.subtitle`에 항상 송신자 닉네임이 들어와 있어서, 일단 subtitle을 즉시 사용하는 단순한 경로로 갔습니다. 옵션 A가 가진 "다른 사용자의 푸시 도달 시 진입 차단" 효과는, 페이로드에 사용자 식별 키가 없는 한 어차피 willPresent 단계에서는 못 막고, 진입 후 `ChatRoomView`가 메시지 API에서 권한 에러를 받으면 자연스럽게 차단되는 동작에 의존합니다.

비로그인 가드를 따로 코드로 만들지 않고 "MainView가 mount된 시점에만 옵저빙"이라는 뷰 계층 구조 자체에 맡긴 것도 의식적인 선택입니다. 가드 한 줄을 추가하는 것보다 구조적으로 보장되는 편이 안전하고 빈틈이 적습니다.

## 시행착오

처음엔 다리 객체 이름을 `PushRouter`로 지었는데 빌드해 보니 `Multiple commands produce '...PushRouter.stringsdata'` 에러가 나면서 실패했습니다. 같은 클래스 이름이 두 디렉토리에 동시에 존재할 때 발생하는 PBXFileSystemSynchronizedRootGroup의 동기화 충돌이라, 우리가 만든 새 파일을 `PushNavigator.swift`로 바꾸고 클래스 이름도 함께 변경해서 해결했습니다. 의미상으로도 "라우터"보다 "내비게이터"가 더 정확한 이름이었습니다.

페이로드 키 구조도 미리 단정하지 않고 디버그 한 줄(`print("Push payload: \(userInfo)")`)을 먼저 willPresent에 심어 두고 실제 푸시를 받아본 다음 설계를 굳혔습니다. 그 출력에서 `to_user_id`나 `receiver_id` 같은 사용자 식별 키가 전혀 없다는 사실을 확인했고, subtitle에 송신자 닉네임이 들어온다는 것도 확정해 옵션 결정이 단순해졌습니다.

## 핵심 파일
- `Ditto/Core/Push/PushNavigator.swift` — AppDelegate와 MainView 사이 다리 (싱글톤, @Observable, @MainActor)
- `Ditto/Core/Push/AppDelegate.swift` — `didReceive`, `launchOptions` 두 경로에서 같은 `routeChatPush(from:)`로 페이로드를 PushNavigator에 적재
- `Ditto/Features/Main/MainView.swift` — `pendingChat` 옵저빙 → 채팅 탭 전환 + `navigationPath` 교체 + `consume()`
- `Ditto/Core/Push/ChatPresence.swift` — 푸시 무음/리스트 갱신 트리거 담당 (이번 작업과 직접 연관은 아니지만 같은 도메인의 협력 객체)
