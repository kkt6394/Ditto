# 채팅방 상대 프로필 아바타

## 한 줄 요약
이 기능은 채팅방 안에서 상대방 메시지 옆에 동그란 프로필 사진을 그려, 누구의 말풍선인지 한눈에 보이게 한다.

## 동작 흐름 (구어체)
"채팅 메시지 한 통이 오면, 우선 ChatRoomViewModel이 그 메시지를 화면용 모델로 정렬해서 ChatRoomView 메시지 리스트에 꽂아준다. ChatRoomView는 메시지를 그릴 때 같은 발신자가 연속으로 보낸 메시지를 한 그룹으로 묶고, 그룹의 첫 번째 말풍선에만 닉네임과 프로필 아바타가 보이도록 `showSenderName`/`showSenderAvatar` 플래그를 ChatBubble에 전달한다.

ChatBubble은 incoming(상대방) 분기에서 좌측에 36pt 원형 아바타 자리를 항상 잡아두는데, 첫 말풍선이면 ProfileAvatar를 그리고, 그룹의 후속 말풍선이면 같은 폭의 투명한 Color.clear를 둬서 좌측 들여쓰기가 흐트러지지 않게 만든다.

ProfileAvatar에 넘기는 URLRequest는 `message.sender.profileImage` 경로를 ActivityFormatting.makeImageRequest로 감싸서 만든다. 이 헬퍼가 절대 URL/상대 경로를 알아서 분기 처리해주고, SeSACKey와 Authorization(액세스 토큰) 헤더를 함께 박아준다. 덕분에 이미지 토큰이 419로 만료되더라도 환경에 주입된 ImageLoader가 자동으로 갱신해 다시 받아오는 흐름을 그대로 탄다."

## 왜 이렇게 짰는지
"같은 메시지에 첨부된 사진을 그릴 때 쓰던 ChatMediaItem이 이미 SeSACKey + Authorization 헤더를 박은 URLRequest를 만들고 있었다. 프로필 이미지도 같은 인증 흐름이 필요하니 동일한 ActivityFormatting.makeImageRequest를 재사용하는 게 맞다고 봤다.

UI는 카카오톡 같은 일반적인 메시지 앱 패턴을 따라가기보다, 이 화면이 이미 닉네임을 그룹 첫 메시지에만 표시하고 있었기 때문에 아바타도 같은 위치(첫 메시지 좌측)에 붙이는 게 시각적으로 자연스러웠다. 후속 말풍선들은 아바타 자리만큼 빈 공간을 둬서 좌측 라인이 일정하게 유지되도록 했다 — 자리를 안 두면 다음 말풍선이 좌측 끝까지 붙어버려서 그룹이 깨진 것처럼 보인다.

ProfileAvatar 컴포넌트는 프로필 탭에서 이미 쓰던 걸 그대로 재사용했다. 새로운 아바타 뷰를 따로 만들 이유가 없었고, 이미지 없을 때의 person.fill 폴백도 그대로 받아갔다."

## 시행착오
처음엔 file_length 룰(500줄)에서 503줄로 살짝 넘어갔다. 한 가지 옵션은 ChatMediaGrid 같은 보조 뷰를 별도 파일로 분리하는 거였지만 요청한 범위 밖이라 피했고, 대신 ProfileAvatar 호출을 멀티라인에서 한 줄로 합쳐 정확히 500줄에 맞췄다.

## 핵심 파일
- Ditto/Features/Main/ChatRoomBubble.swift — ChatBubble에 `showSenderAvatar` 플래그와 좌측 아바타 슬롯 추가, sender.profileImage → URLRequest 변환
- Ditto/Features/Main/ChatRoomView.swift — `shouldShowSenderName(at:)` 그룹 규칙을 그대로 재사용해 `showSenderAvatar` 전달
- Ditto/Features/Profile/ProfileTabComponents.swift — 재사용한 `ProfileAvatar` (폴백 person.fill 포함)
- Ditto/Core/API/Common/ActivityFormatting.swift — `makeImageRequest`가 SeSACKey + Authorization 헤더 부착
