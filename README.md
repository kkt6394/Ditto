# DITTO

DITTO는 다양한 투어, 액티비티, 체험 상품을 탐색하고 구매할 수 있는 iOS 앱입니다.

이 프로젝트는 Xcode 환경에서 SwiftUI 기반으로 개발하며, 단방향 데이터 흐름과 테스트 가능한 구조를 목표로 합니다. 프로젝트가 진행됨에 따라 기능 정의, 구조 설계, 문서 내용을 함께 발전시켜 나갑니다.

## 1. Project Summary

- Platform: iOS
- Language: Swift
- UI Framework: SwiftUI
- Architecture: MVVM
- Networking: URLSession
- Concurrency: Swift Concurrency
- State Management Experiment: TCA 일부 적용
- IDE: Xcode

## 2. Project Goal

이 프로젝트의 목표는 다양한 액티비티 상품을 판매하는 iOS 앱을 구현하는 것입니다.

주요 목표:
- 사용자가 액티비티 상품을 쉽고 직관적으로 탐색할 수 있는 경험 제공
- 상품 상세 확인부터 구매까지 자연스러운 사용자 흐름 설계
- 확장 가능하고 유지보수가 쉬운 구조 구축
- 테스트 가능한 코드베이스 설계

## 3. Core Features

현재 기준으로 예상하는 핵심 기능은 다음과 같습니다.

- 액티비티 상품 목록 조회
- 카테고리별 상품 탐색
- 상품 상세 정보 확인
- 예약 및 구매 흐름 제공

추가 기능은 프로젝트 진행에 따라 구체화하고 확장합니다.

## 4. Architecture

프로젝트의 기본 구조는 MVVM을 기반으로 설계합니다. 화면 단위로 View와 ViewModel의 역할을 분리하고, 네트워크 요청과 같은 비동기 작업은 Swift Concurrency를 중심으로 처리합니다.

구성 원칙:
- View는 화면을 렌더링하고 사용자 입력을 ViewModel에 전달합니다.
- ViewModel은 화면 상태를 관리하고 사용자 액션에 따른 비즈니스 흐름을 처리합니다.
- Model과 Service는 데이터 구조와 외부 API 호출을 담당합니다.
- 네트워크 요청은 `async/await` 기반으로 구현합니다.
- Combine은 기본 설계에 포함하지 않고, 필요성이 명확할 때 제한적으로 검토합니다.

### TCA Experiment

학습과 비교를 위해 특정 독립 뷰 하나에는 TCA를 실험적으로 적용합니다. 단, 앱 전체의 기본 아키텍처는 MVVM으로 유지합니다.

TCA 적용 원칙:
- 전역 상태나 핵심 인증 흐름이 아닌 독립적인 기능을 대상으로 합니다.
- 한 화면 안에서 MVVM과 TCA를 동시에 섞지 않습니다.
- TCA 화면은 Store, State, Action, Reducer 구조를 독립적으로 가집니다.
- 비동기 작업은 TCA에서도 Swift Concurrency 기반으로 처리합니다.

## 5. Development Principles

- 요구사항을 먼저 정리한 뒤 구현을 진행합니다.
- 큰 변경은 작업 계획과 영향 범위를 먼저 공유합니다.
- 코드 변경 후에는 가능한 범위에서 빌드와 검증을 수행합니다.
- 테스트 가능하고 유지보수하기 쉬운 구조를 우선합니다.
- 협업 규칙은 `AGENTS.md`를 따릅니다.

## 6. Project Structure

현재 문서 구조는 다음과 같습니다.

```text
DITTO/
├── AGENTS.md
├── README.md
└── docs/
```

프로젝트 구조는 개발 진행에 따라 점진적으로 구체화합니다.

## 7. Documentation

- 프로젝트 개요 및 개발 방향: `README.md`
- 협업 규칙: `AGENTS.md`
- 요구사항, 작업 목록, 결정 사항: `docs/`

## 8. Next Steps

초기 단계에서 우선 진행할 작업은 다음과 같습니다.

- 핵심 사용자 시나리오 정의
- 주요 화면 구조 정리
- 도메인 모델 초안 작성
- 네트워크 구조 설계
- MVVM 기준 폴더 구조와 역할 정리
- TCA 실험 대상 뷰 선정
