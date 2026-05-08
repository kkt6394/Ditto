# 인증 토큰 복원

## 한 줄 요약
이 기능은 새 빌드/재설치 후에도 Keychain의 액세스/리프레시 토큰을 그대로 살려 자동 로그인이 유지되도록 한다.

## 동작 흐름 (구어체)
앱이 켜지면 ContentView가 `AuthManager()` 를 만든다. 이전 구현에서는 init에서 UserDefaults의 `auth.didPrepareKeychain` 키를 보고 false면 (= 첫 실행 또는 재설치) Keychain의 토큰을 한 번 정리하고 flag를 true로 set했다. 의도는 "앱 삭제 후 재설치된 시점에 이전 사용자 잔존 토큰이 자동으로 인증되어 들어가지 않게" 막는 것이었다.

문제는 새 빌드(개발 중 Run, 릴리즈 후 OTA 재설치 포함) 시 시뮬레이터/디바이스가 앱을 reinstall로 처리하면서 UserDefaults가 초기화되면, Keychain 토큰은 살아 있는데 flag만 사라져서 매번 Keychain을 비워버리고 로그인 화면으로 빠진다는 점이었다.

지금은 그 prepare 로직 자체를 제거했다. `AuthManager.init` 은 단순히 `tokenStore.loadTokens()` 를 한 번 시도해, 성공하면 그 토큰으로 자동 로그인 상태가 되고 실패하면 비로그인 상태로 시작한다. 새 빌드/재설치 직후라도 Keychain에 유효한 토큰이 남아 있으면 그대로 인증된 상태로 메인에 진입한다.

토큰이 만료된 케이스는 NetworkManager가 419(만료) 응답을 받았을 때 리프레시 토큰으로 갱신하는 별도 흐름에서 처리되고, 갱신 실패 시 `signOut(reason: .sessionExpired)` 가 호출되어 정상적으로 로그인 화면 + 안내 토스트가 노출된다. 즉 "정상 만료" 와 "정상 자동 로그인" 둘 다 그대로 동작하고, 사라진 건 "새 빌드 한 번 했다고 강제로 로그아웃되는 부작용" 뿐이다.

## 왜 이렇게 짰는지
원래 prepare 로직이 막으려던 시나리오 — "재설치 후 잔존 Keychain 토큰으로 다른 사용자가 자동 로그인" — 는 실제로는 발생 빈도가 낮고, 발생하더라도 서버가 만료/유효하지 않은 토큰에 419로 응답해 정상 sign-out 흐름을 타게 되어 있다. 반면 새 빌드마다 강제 로그아웃은 개발 사이클·일반 OTA 업데이트마다 매번 발생해 UX/디버깅 비용이 컸다. 트레이드오프상 prepare 로직 제거가 맞다고 판단했다.

flag 위치를 UserDefaults → Keychain으로 옮기는 절충안도 검토했는데, 결국 "재설치 시 정리"라는 본래 보안 효과가 사라지는 건 마찬가지라(둘 다 keychain에 같이 남음) 그냥 단순히 제거하는 쪽으로 갔다.

## 시행착오
- 처음엔 Keychain flag 저장 방식으로 옮길까 고민했지만, 보안 효과가 같이 무효화되는 점에서 제거와 사실상 동일했다. 그러면 단순한 쪽이 낫다고 판단.
- 기존 테스트 두 건(`initClearsStoredTokensOnFirstLaunchAfterInstall`, `initKeepsStoredTokensAfterFirstLaunchPreparation`) 은 prepare 로직 자체를 검증하던 거라 의미가 사라져서 제거하고, 일반적인 "저장된 토큰을 그대로 복원" / "토큰 없으면 비인증" 두 케이스만 남겼다.

## currentUserId 캐시 (관련 작업)
PostDetail 본인 글 판별을 위해서는 myProfile API가 성공해야 했는데, fetch 실패 등으로 nil이 되면 trash 버튼이 노출되지 않는 문제가 있었다. 이 문제를 해결하기 위해 AuthManager에 `currentUserId` 를 캐시하는 흐름을 추가했다.

LoginResponse(이메일/카카오/애플 모두) 는 이미 `userId` 를 함께 내려 주므로, 로그인 직후 `authManager.setCurrentUserId(response.userId)` 한 줄로 저장해 둔다. 이 값은 UserDefaults `auth.currentUserId` 키에도 영속화돼서 앱 재실행 후에도 유지된다 (만료/sign-out 시는 자동 정리).

PostDetailViewModel은 init에서 `authManager.currentUserId` 를 먼저 받아 currentUserId를 즉시 채우고, 비어 있을 때만 load() 안의 myProfile fetch fallback을 시도한다. 그 fallback에서도 성공하면 AuthManager에 저장해 다른 화면들이 즉시 본인 판별을 할 수 있도록 한다.

## 핵심 파일
- `Ditto/Core/Auth/AuthManager.swift` — `prepareKeychainIfNeeded` 제거, `currentUserId` 상태 + UserDefaults 영속화 + `setCurrentUserId` 추가, sign-out 시 함께 정리.
- `Ditto/Features/Auth/Login/LoginViewModel.swift` — 이메일/카카오/애플 로그인 성공 시 `authManager.setCurrentUserId(response.userId)` 호출.
- `Ditto/Features/Post/PostDetailViewModel.swift` — init에서 authManager.currentUserId로 즉시 초기화, fallback fetch 성공 시 authManager에 역방향 저장.
- `DittoTests/...` — 4개 stub(`StubAuthManager`/`StubLoginAuthManager`/`StubSearchAuthManager`/`StubMainAuthManager`)에 `currentUserId`, `lastSignOutReason`, `setCurrentUserId(_:)`, `signOut(reason:)` 등 protocol 변경분 반영.
