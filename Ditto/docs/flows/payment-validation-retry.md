# 결제 검증 재시도 / 이중결제 방어

## 한 줄 요약
결제는 끝났는데 검증 호출만 실패했을 때 `impUid`를 잃지 않고 **자동 재시도(메모리 내) + 수동 재시도(사용자 버튼) + 부팅 복구(영속화)** 3단으로 받아내 이중결제를 막고, PG 결제창이 응답 없는 상황도 ScenePhase로 감지해 사용자에게 빠져나갈 길을 만든다.

## 동작 흐름 (구어체)
사용자가 PG 결제창에서 카드 결제를 끝내면 아임포트 SDK가 `impUid`를 콜백으로 던져준다. 그러면 `PaymentViewModel`이 `phase`를 `.validating(orderCode, impUid)`로 바꾸고 서버에 `/v1/payments/validation`을 호출한다.

여기서 만약 네트워크가 끊기거나 서버가 5xx를 던지면, 내부적으로 0.5초 → 1초 → 2초 백오프로 최대 4번까지 자동 재시도한다. 같은 `impUid`로 검증을 거는 건 멱등이라 안전하다. 4xx 같은 비즈니스 에러는 재시도해도 결과가 안 바뀌니까 즉시 실패 처리한다.

자동 재시도 4번까지 다 실패하면 `phase`를 `.validationFailed(orderCode, impUid, message)`로 바꾼다. 이 상태가 핵심이다 — 기존엔 그냥 `.failed`로 떨어져서 사용자가 "다시 시도" 누르면 `.idle`로 돌아가 결제부터 다시 했는데, 이제는 `impUid`를 보존한 별도 상태로 남는다.

화면에는 "결제 확인이 필요해요 / 결제는 정상 처리됐지만 확인이 지연되고 있어요" 메시지와 "결제 확인 다시 시도" 버튼만 보여준다. 닫기 버튼은 일부러 안 만들었고 `canDismiss`도 `false`로 막았다. 사용자가 실수로 닫고 다시 결제해서 이중결제되는 걸 막기 위해서다.

사용자가 버튼을 누르면 `viewModel.retryValidation()`이 호출되는데, 이건 PG 결제창을 다시 띄우지 않고 같은 `impUid`로 검증만 다시 친다.

여기까지는 메모리에 살아있을 때 얘기다. 만약 OS가 메모리 부족으로 앱을 강제 종료시키거나, 사용자가 앱을 강제 종료하면 메모리상의 phase는 통째로 사라진다. 그래서 검증 단계 진입 시에 `PendingPaymentValidationStore`에 `(orderCode, impUid, savedAt)`을 UserDefaults로 저장해둔다. 검증이 성공하면 clear, 실패해도 store는 일부러 남겨둔다.

다음에 앱을 켜면 `ContentView.task`에서 인증 확인이 끝난 직후 `PaymentRecoveryService.recoverIfNeeded()`가 돌면서 store에 데이터가 있으면 같은 `impUid`로 조용히 검증을 재시도한다. 성공하면 store clear, 4xx면 영구 실패로 보고 clear, 그 외 일시 실패는 store 유지하고 다음 부팅에서 또 시도한다. 24시간 지난 데이터는 load 시점에 자동 폐기 (서버도 어차피 거부할 가능성이 높아서).

## PG 결제창 stalled 처리 (백그라운드 + 무응답)

또 하나의 별개 문제는 검증 단계가 아니라 그 이전, **PG 결제창 자체가 응답이 없는 상황**이다. SDK 콜백이 영영 안 오는 경우(드물지만 가능)인데 그러면 phase가 `.awaitingPayment`로 영원히 멈추고 `canDismiss=false`라 사용자가 화면을 못 닫는 데드락이 생긴다.

이걸 막으려고 `awaitingPayment` 진입 시 `startedAt`을 같이 들고 있다가 `PaymentView`에서 `@Environment(\.scenePhase)`로 백그라운드→active 전환을 감지한다. 복귀 시점에 `viewModel.checkAwaitingPaymentStaleness()`을 호출해서 startedAt 기준 3분 이상 흘렀으면 `awaitingPaymentStalled` 상태로 마킹한다.

stalled 상태가 되면 `pendingPayment`가 nil을 반환하기 때문에 `fullScreenCover`의 `launcherBinding`이 nil이 되어 PG 결제창이 자동으로 닫히고 PaymentView 본체로 돌아온다. 본체 화면에는 "결제 응답이 늦어요 / 결제내역에서 정상 결제 여부 확인 후 다시 시도해 주세요 / 결제 취소하고 닫기" 안내가 나오고 사용자가 명시적으로 취소하면 phase가 `.failed`로 바뀐다.

뒤늦게 SDK가 콜백을 줄 가능성도 있어서 `handlePaymentSuccess`는 `awaitingPayment` 뿐 아니라 `awaitingPaymentStalled`에서도 받아주도록 했다. 결제가 실제로 됐다면 검증까지 마무리되고, 안 됐으면 사용자가 닫는 쪽이다.

추가로 `OrderRouter.create`와 `PaymentRouter.validate/receipt`에는 URLRequest timeoutInterval을 30초로 지정했다 (기본 60초보다 짧게). `APIRouter`에 `timeoutInterval: TimeInterval?` 옵셔널을 추가해서 라우터별로 지정할 수 있게 했고, 결제 외 API는 기본값 그대로다. 사용자가 결제 화면에서 멈춰 있는 시간을 줄이고 retry 루프가 더 빨리 돌아가게 만든다.

## 왜 이렇게 짰는지
- **`impUid`를 Phase에 묶어둔 이유**: 검증 실패 시 `impUid`가 사라지면 사용자가 다시 결제를 시도할 수밖에 없고, 그러면 PG에는 두 번 결제가 찍힌다. `validating`과 `validationFailed` 둘 다 `impUid`를 associated value로 들고 있게 해서 이 경로를 끊었다.
- **`failed`와 `validationFailed`를 분리한 이유**: 두 상태는 사용자에게 보여줘야 할 행동이 정반대다. 일반 `failed`는 "처음부터 다시 시도", `validationFailed`는 "결제는 됐으니 검증만 다시". 같은 case로 묶고 분기 처리하면 readability가 나빠지고 실수로 reset 호출하는 사고가 생기기 쉬워서 case를 쪼갰다.
- **자동 재시도를 ViewModel에 넣은 이유**: NetworkManager 일반 retry로 올리면 모든 호출에 영향이 가서 위험하다. 결제 검증만 멱등성이 보장되는 특수 호출이라 ViewModel 레벨에서 명시적으로 처리했다.
- **`canDismiss = false`**: SwiftUI sheet에 swipe-to-dismiss가 있어서 결제 됐는데 사용자가 무심코 내리면 영수증을 잃는다. 검증 끝날 때까지 강제로 막는 쪽이 안전하다.
- **영속화를 UserDefaults로 한 이유**: `impUid`는 결제 비밀이 아니고 노출되도 사용자 본인 결제 검증 외에 악용 경로가 없다. JWT 같은 토큰과는 성격이 달라 Keychain까지 갈 필요는 없다고 판단했다. UserDefaults가 가볍고 충분.
- **복구 시 사용자에게 UI 안 띄운 이유**: 부팅 시점에 알림창을 띄우면 무슨 결제인지 모르는 상태에서 사용자가 혼란스러울 수 있다. 또 대부분 정상 케이스에서는 store가 비어 있으니까 조용히 처리하는 게 자연스럽다. 만약 복구도 실패하면 다음 부팅 때 또 시도되고, 그 사이에 사용자는 OrderListView에서 누락된 주문을 본인이 인지할 수 있다. (OrderListView 표시 보강은 P2로 분리)
- **stalled 임계값을 3분으로 둔 이유**: 카드사 인증 앱에서 OTP 입력하거나 비밀번호 한두 번 틀리면 1~2분은 충분히 걸린다. 너무 짧으면 정상 결제도 stalled로 잘못 판단해서 사용자를 혼란스럽게 한다. 3분이면 일반 결제는 끝나고도 남는 시간이라 잘못 판정 위험이 낮다.
- **stalled에서도 SDK 콜백을 받아준 이유**: 사용자가 stalled 화면을 열어둔 채 카드사 앱에서 인증을 완료하면 뒤늦게 SDK가 success 콜백을 줄 수 있다. 이걸 거부해버리면 결제는 됐는데 검증 호출이 안 들어가서 영수증 미수신이 된다. 그래서 `handlePaymentSuccess`에서 `awaitingPayment` / `awaitingPaymentStalled` 둘 다 허용했다.
- **결제 API timeout만 30초로 줄인 이유**: 모든 API에 일률로 짧은 timeout 적용하면 큰 응답(목록, 이미지 metadata 등)에서 무고한 실패가 늘어난다. 결제는 응답 본문이 작고 사용자가 화면 앞에서 기다리는 호출이라 일찍 실패시키는 trade-off가 맞다.

## 시행착오
처음엔 그냥 일반 `.failed` 상태에서도 retry 시도해볼까 했는데, 검증과 무관한 PG 단계 실패(사용자 결제창 취소 등)에서도 자동 retry가 돌면 의미 없는 호출이 늘어나고 UX도 이상해진다. 그래서 검증 단계 전용 상태(`validationFailed`)를 별도로 만드는 쪽으로 갔다.

## 핵심 파일
- `Ditto/Features/Payment/PaymentViewModel.swift` — `Phase`에 `validationFailed`/`awaitingPaymentStalled` 추가, `awaitingPayment`에 `startedAt` 보관, `performValidation` 헬퍼에 retry 루프 + store save/clear, `retryValidation()` / `checkAwaitingPaymentStaleness()` / `cancelStalledPayment()` 공개 메서드, `isRetriableValidationError` 판별기
- `Ditto/Features/Payment/PaymentView.swift` — `.validationFailed` / `.awaitingPaymentStalled` 분기 UI, `@Environment(\.scenePhase)` 감지로 stalled 마킹 트리거
- `Ditto/Core/Persistence/PendingPaymentValidationStore.swift` — UserDefaults 기반 (orderCode, impUid, savedAt) 영속화, 24시간 만료
- `Ditto/Features/Payment/PaymentRecoveryService.swift` — 부팅 시 store에 남은 미검증 결제를 자동으로 재검증
- `Ditto/ContentView.swift` — `.task`와 `onChange(authManager.isAuthenticated)`에서 복구 서비스 호출
- `Ditto/Core/Network/APIRouter.swift` — `timeoutInterval: TimeInterval?` 옵셔널 추가 (default nil)
- `Ditto/Core/Network/NetworkManager.swift` — 라우터에 timeout 지정되어 있으면 URLRequest에 적용
- `Ditto/Core/API/Payment/PaymentRouter.swift` / `Ditto/Core/API/Order/OrderRouter.swift` — 결제·주문 호출에 30초 timeout 지정
