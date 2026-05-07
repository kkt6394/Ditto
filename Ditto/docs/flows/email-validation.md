# 이메일 중복검사

## 한 줄 요약
이 기능은 회원가입 화면에서 사용자가 이메일을 입력하면 600ms 디바운스 후 서버 `/v1/users/validation/email`을 호출해 중복 여부를 판정하고, 사용 가능한 이메일이어야만 가입 버튼이 활성화되도록 막는다.

## 동작 흐름 (구어체)
"사용자가 이메일 텍스트필드에 한 글자씩 타이핑하면 SwiftUI의 `.onChange`가 매번 `viewModel.scheduleEmailCheck()`를 부른다. 그러면 ViewModel은 이전에 진행 중이던 검사 Task가 있으면 즉시 cancel하고, 새 입력값을 가지고 새로운 Task를 만든다. 이 Task는 600ms 동안 `Task.sleep`으로 기다리는데, 사용자가 그 사이에 또 타이핑하면 같은 흐름이 반복돼서 이전 Task는 취소되고 새 Task만 살아남는다. 즉 사용자가 타이핑을 멈춘 시점에서 600ms가 지나면 그때서야 한 번만 서버에 요청이 나간다.

서버에서 200이 떨어지면 `EmailValidationResponse`의 message를 그대로 들고 `emailCheckState = .available(message)`로 바꾸고, 그러면 SignUpView의 EmailCheckRow가 초록 체크 아이콘과 함께 메시지를 그려준다. 동시에 `isEmailVerified`가 true가 돼서 가입 버튼이 그제서야 활성화된다.

만약 409가 떨어지면 NetworkManager가 `NetworkError.statusCode(409, message:, data:)`로 던져주는데, ViewModel은 catch해서 status code를 분기한 다음 `.unavailable(서버메시지)`로 상태를 바꾼다. 그러면 EmailCheckRow가 빨간 X 아이콘으로 '사용이 불가한 이메일입니다.'를 보여주고 버튼은 계속 비활성. 400이 떨어지면 형식 오류로 보고 `.formatInvalid` 처리.

서버 호출 전에도 클라이언트에서 한 번 거른다. 입력이 비어있으면 `.idle`, `@`가 안 들어있으면 `.formatInvalid`로 바꿔서 굳이 네트워크를 안 탄다. 그리고 마지막으로 검사한 이메일과 현재 입력값이 똑같고 그게 이미 사용 가능 판정을 받았다면 또 호출하지 않는다."

## 왜 이렇게 짰는지
- **디바운스를 ViewModel에 둔 이유**: View의 `.onChange`에 디바운스 로직(타이머/Task)을 직접 넣으면 View가 비동기 상태를 들고 있어야 해서 지저분해진다. ViewModel이 in-flight Task를 들고 cancel하는 게 자연스럽고 테스트도 가능.
- **enum으로 상태를 표현한 이유**: idle/checking/available/unavailable/formatInvalid/error를 각각 Bool 플래그로 들고 있으면 동시에 두 상태가 켜지는 버그가 생기기 쉽다. enum이면 항상 한 가지 상태만 표현 가능.
- **서버 메시지를 그대로 표시**: 200/409 응답이 message 한 필드만 내려오니까 클라에서 굳이 다른 문구를 만들 필요가 없다. 서버 정책이 바뀌어도 자동으로 반영됨. 다만 message가 nil인 edge에 대비해 fallback 문자열은 둠.
- **`isSignUpButtonEnabled`에 `isEmailVerified` 추가**: 사용자가 이메일을 안 검사하고 그냥 가입 버튼 누르면 서버가 join 단계에서 409로 거를 텐데, 그 전에 막아야 사용자 경험이 좋다. 또 검사 통과 후 이메일을 다시 수정하면 lastCheckedEmail과 달라지고 .checking으로 떨어져서 버튼이 다시 비활성화됨.

## 시행착오
해당 없음. (한 번에 명세 확인 → DTO 추가 → ViewModel 상태머신 → View onChange/배지 순서로 진행)

## 핵심 파일
- `Ditto/Core/API/Auth/AuthRouter.swift:11` — 기존 `validateEmail(EmailValidationRequest)` 케이스를 그대로 사용 (이전엔 정의만 있고 호출처 0건이었음)
- `Ditto/Core/API/Auth/AuthRequest.swift:50` — 기존 `EmailValidationRequest { email }`
- `Ditto/Core/API/Auth/AuthResponse.swift` — `EmailValidationResponse { message }` 추가
- `Ditto/Features/Auth/SignUp/SignUpViewModel.swift` — `EmailCheckState` enum, `scheduleEmailCheck()`, `performEmailCheck()`, `applyEmailCheckError()`, `isEmailVerified`, `isSignUpButtonEnabled` 강화
- `Ditto/Features/Auth/SignUp/SignUpView.swift` — 이메일 필드에 `.onChange` 트리거, `EmailCheckRow` 상태 배지 추가
