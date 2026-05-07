# 회원탈퇴 dead code 제거

## 한 줄 요약
앱에 회원탈퇴 버튼/Router/DTO/ViewModel 메서드가 모두 있었지만 SeSAC 서버 명세에는 해당 path가 정의되어 있지 않아, 호출하면 무조건 444(잘못된 url)가 떨어지는 dead path였다. 명세 검증 후 관련 코드를 전부 제거했다.

## 왜 이렇게 짰는지
"코드만 봐서는 회원탈퇴가 정상 작동하는 것처럼 보였다 — UserRouter에 `withdraw` case가 있고, ProfileViewModel.withdraw()에서 호출하고, ProfileTabView에 alert까지 붙어 있었으니까. 그래서 처음엔 회원탈퇴 API가 잘 연동되어 있다고 생각했다. 그런데 사용자가 'activity-api-docs / activity-openapi-paths에 회원탈퇴 API 없지 않냐'고 지적해서 명세를 다시 확인했더니, openapi paths에 정의된 `/v1/users/*` 경로 10개 어디에도 `withdraw`가 없었다. 흥미롭게도 `WithdrawResponseDTO` 스키마는 schemas 섹션에 남아 있었는데, 이를 사용하는 path는 등록되지 않은 상태였다 — 즉 명세 leftover다.

이 시점에서 옵션이 4개 있었다: A) 모두 제거, B) UI는 두되 호출만 비활성화, C) 그대로 두고 친절한 에러 메시지, D) 실서버에 직접 호출해 444 떨어지는지 확인부터. C는 영구적인 dead path가 남아 비추천. D는 매번 호출해보지 않고도 명세가 단일 정답이라면 확실히 444가 떨어질 게 거의 확정이라 생략 가능. B는 디자인 의도를 살리는 안전한 선택이지만 dead code가 남는다. 결국 A를 선택해 깔끔하게 정리했다 — 명세에 없는 기능을 코드에 두는 건 향후 리팩토링·유지보수 시 잘못된 정보를 주기 때문이다."

## 시행착오
"내가 처음 API 활용 감사 보고서를 만들었을 때 AuthRouter만 보고 회원탈퇴 미연동이라고 잘못 보고했다. 사용자가 코드 레벨에서 UserRouter.withdraw가 있다고 알려줘서 정정했고, 그 다음 사용자가 명세 문서를 보라고 해서 그제서야 path가 빠진 걸 발견했다. 교훈: '코드에 호출이 있다 = 잘 동작한다'가 아니다. 명세까지 따로 봐야 한다."

## 핵심 파일
- `Ditto/Core/API/User/UserRouter.swift` — `case withdraw` 및 모든 switch 분기에서 패턴 제거
- `Ditto/Core/API/User/UserResponse.swift` — `WithdrawResponseDTO` struct 제거
- `Ditto/Features/Profile/ProfileViewModel.swift` — `isWithdrawing` 프로퍼티, `withdraw()` 메서드 제거
- `Ditto/Features/Profile/ProfileTabView.swift` — alert, 회원탈퇴 버튼, `isPresentingWithdrawConfirm` State 제거
