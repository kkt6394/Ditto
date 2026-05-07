# 액티비티 PDF 추출 v2 (사진 wrap-around + 월/년 단위)

## 한 줄 요약
이 기능은 사용자가 결제·참여한 액티비티 내역을 활동 리포트(월/년 단위) 또는 단건 추억 페이지 PDF로 추출하게 해준다. 본문은 액티비티 사진을 큼직하게 깔고 텍스트가 사진 주변을 따라 흐르도록 TextKit `exclusionPaths`를 사용한다.

## 동작 흐름 (구어체)

### 활동 리포트 시나리오 (월/년 단위)
주문 내역 화면 우상단 "리포트 PDF" 버튼을 누르면 fullScreenCover로 ExportView가 올라온다. 첫 단계는 **시점 선택** — `ActivityReportScope.availableScopes(from:)`이 주문들의 paidAt을 훑어서 "전체 / 2026년 / 2025년 / 2026년 5월 / ..." 옵션을 정렬해 보여준다. 사용자가 한 옵션을 고르고 "다음(손글씨)"를 누르면 ViewModel이 그 scope으로 주문을 필터링하고, **걸러진 주문들의 첫 썸네일을 모두 백그라운드에서 다운로드**한다(`TaskGroup` + `RemoteImageLoader.load(request:pointSize:)`).

이미지 다 받으면 markup 단계로 넘어가서 PaperKit 캔버스가 뜨고 표지 손글씨를 그릴 수 있다. "PDF 미리보기"를 누르면 `Task.detached`로 PDF를 굽는다. Renderer는 표지 → 요약 통계(총건수·총지출·기간·카테고리 분포) → **각 액티비티마다 한 페이지**(큰 사진 + 사진 주변에 흐르는 텍스트) → 마무리 페이지 순으로 그린다.

본문 페이지의 핵심은 `NSTextContainer.exclusionPaths`다. 사진이 들어갈 사각형을 컨테이너 좌표계로 변환해서 exclusion에 등록하면, 같은 컨테이너 안에서 텍스트가 그 영역을 자연스럽게 피해 흐른다. 사진 우측에서 시작해 사진 아래로 내려와 페이지 폭 전체로 넓어진다.

PDF 완성되면 `PDFView`로 미리보기를 보여주고 `ShareLink`로 공유 시트가 뜬다. 파일명은 `Ditto_활동리포트_2026-05.pdf` 또는 `Ditto_활동리포트_2026.pdf` 처럼 scope을 반영한다.

### 단건 추억 PDF 시나리오
영수증 화면 우상단 "PDF" 버튼을 누르면 같은 패턴으로 ExportView가 올라온다. v2에서 **결제 영수증 컨셉을 폐기**하고, 액티비티 이미지가 페이지 상단을 풀폭 헤로 이미지로 차지하게 했다. 진입 직후 단건 thumbnail을 백그라운드에서 다운로드(`bootstrap()`)하고 markup 단계로 진입한다.

PaperKit 캔버스에서 "추억 메모"를 그리고 "PDF 미리보기"를 누르면 한 페이지 안에:
- 상단 360pt: 액티비티 이미지 (둥근 사각형 + aspect-fill clip)
- 그 아래: 액티비티 제목 (Paperlogy 30pt)
- 그 아래: 카테고리·결제 금액·결제일 메타 텍스트
- 우하단: 사용자 추억 메모(PaperKit 캡쳐 이미지)

가 들어간 PDF가 완성된다. ShareLink로 공유.

## 왜 이렇게 짰는지

**TextKit의 진가는 wrap-around에 있다.** v1에서는 단순 페이지 분할만 썼는데, 사용자 피드백으로 사진 주변에 텍스트가 흐르도록 바꿨다. `NSTextContainer.exclusionPaths`가 그걸 가능하게 해주는 핵심 API. layout manager가 한 컨테이너 안에서 글리프를 흘리며 exclusion path를 만나면 우회한다. 사진을 좌상단에 두면 텍스트가 사진 우측 → 사진 아래로 자연스럽게 내려간다.

**영수증 컨셉을 버리고 사진 중심으로.** 결제 ID, 카드 번호, PG, 결제 상태 같은 메타는 사용자에게 의미가 적다. 사용자가 진짜 보고 싶은 건 "그날 무엇을 했는지"고 그 한 장의 사진이다. 그래서 v2에서는 ReceiptPDFRenderer를 액티비티 이미지 풀헤로 + 제목/카테고리/금액 정도만 보여주는 추억 페이지로 바꿨다. PaperKit 캔버스의 의미도 "사인"에서 "추억 메모"로.

**월/년 단위 scope 선택.** "이번 달 한 액티비티만", "올해 한 액티비티만" 같은 부분 추출 욕구가 자연스럽다. enum `ActivityReportScope { case all / year(Int) / month(Int, Int) }`를 두고 paidAt을 파싱해서 사용 가능한 scope 옵션을 자동 생성한다. 첫 진입 단계에서 이걸 보여주고, 사용자가 고른 뒤에야 이미지 다운로드를 시작해 불필요한 트래픽을 줄였다.

**이미지 다운로드는 ViewModel이 책임진다.** `confirmScope()`에서 `withTaskGroup`으로 병렬 다운로드. 인증 헤더가 필요한 요청은 `ActivityFormatting.makeImageRequest(from:configuration:accessToken:)`으로 빌드하고, 401 자동 갱신을 위해 환경 `imageLoader`(NetworkManager)가 있으면 우선 사용한다. 다운로드 실패한 항목은 placeholder("사진을 불러올 수 없어요")로 표시.

**SwiftUI environment가 init에 못 들어오는 문제.** `@Environment(\.imageLoader)`는 View body가 평가될 때만 값이 들어온다. ViewModel을 init에서 들고 가려면 imageLoader를 미리 갖고 있을 수가 없다. 그래서 ViewModel에 `var imageLoader`를 노출하고 View `.task`에서 setter로 주입하는 패턴을 썼다.

**Type body 길이 관리.** SwiftLint type_body_length 한계가 300인데 Renderer가 자주 넘친다. 그래서 같은 파일 안에 `private extension ActivityReportPDFRenderer`를 두 개 두고 헬퍼/wrap-around 본문을 분리했다. extension은 별도 type body로 카운트되므로 main struct가 짧아진다.

## 시행착오

**PaperKit 정확한 API.** iOS 26 신규라 정확한 심볼명이 헷갈렸다. PencilKit `PKCanvasView`로 동등 구현 후 `PaperKitMarkupCanvasView`라는 단일 wrapper 파일로 격리해뒀다. 추후 docs 확인하면 그 한 파일만 swap.

**v1 → v2 회수.** v1에서 longform 본문(텍스트만 페이지 분할)으로 짠 부분이 사용자 피드백("TextKit 쓰는 이유가 안 살아난다")으로 다 갈아엎혔다. plan부터 다시 정리하고 도메인을 재작성했다. 사진 + wrap-around가 시각적 임팩트가 훨씬 크다.

**SwiftLint 위반 사전 검증 누락.** 처음에는 빌드해 보지 않고 코드를 작성해서 사용자가 빌드 시 lint 에러를 한꺼번에 떠안았다. SwiftLint CLI가 PATH에 없어서 못 찾았는데, SPM 플러그인 artifact bundle 안 바이너리 경로를 메모리에 저장해서 이제는 코드 변경 후 직접 돌려본다.

## 핵심 파일

### 공통 인프라 (`Ditto/Core/PDF/`)
- `PDFPaper.swift` — A4/Letter 사이즈·마진·색 토큰
- `PDFRenderer.swift` — `UIGraphicsPDFRenderer` wrapper
- `PDFTextLayout.swift` — TextKit 페이지 분할기 (현재는 사용 안 하지만 다른 용도에 남겨둠)
- `PDFAttributedStringBuilder.swift` — Pretendard/Paperlogy NSAttributedString 빌더
- `PDFFileNaming.swift` — 파일명·임시 디렉토리 규칙
- `PDFShareItem.swift` — ShareLink Transferable

### 활동 리포트 (`Features/PDFExport/ActivityReport/`)
- `ActivityReportScope.swift` — enum + 필터 + availableScopes
- `ActivityReportAggregator.swift` — 통계 + paidAt 파싱(internal)
- `ActivityReportSnapshot.swift` — scope·thumbnails·markup 포함 값 객체
- `ActivityReportPDFRenderer.swift` — 사진 + exclusionPaths wrap-around 본문
- `ActivityReportExportView.swift` — Phase 머신: scopeSelection → loadingImages → markup → rendering → ready
- `ActivityReportExportViewModel.swift` — scope 적용·이미지 병렬 다운로드·PDF 굽기

### 단건 추억 (`Features/PDFExport/Receipt/`)
- `ReceiptPDFSnapshot.swift` — 액티비티 메타 + activityImage + signatureOverlay
- `ReceiptPDFRenderer.swift` — 헤로 이미지 + 제목 + 메타 + 사인
- `ReceiptExportView.swift` — Phase 머신: loadingImage → markup → rendering → ready
- `ReceiptExportViewModel.swift` — bootstrap에서 단건 이미지 다운로드 후 markup 진입

### 공통 UI (`Features/PDFExport/Components/`)
- `PaperKitMarkupCanvasView.swift` — PencilKit 기반 wrapper (PaperKit swap 단일 지점)
- `PDFPreviewView.swift` — `PDFView` wrapper
- `PDFExportNavigationBar.swift` — Export 화면 공통 네비바

### 진입점
- `Features/Order/OrderListView.swift` — receiptAction signature에 thumbnailPath 추가, fullScreenCover에서 imageRequestBuilder 주입
- `Features/Order/OrderListReportButton.swift`
- `Features/Receipt/ReceiptView.swift` — init에 thumbnailPath 추가, fullScreenCover에서 메타+thumbnail 주입
- `Features/Receipt/ReceiptPDFExportButton.swift`
- `Features/Main/MainRoute.swift` — `.receipt` case에 thumbnailPath 추가
- `Features/Main/MainView.swift` — orderList → receipt routing에 thumbnailPath 전달
- `Ditto.xcodeproj/project.pbxproj` — deployment target 26 (v1에서 처리)
