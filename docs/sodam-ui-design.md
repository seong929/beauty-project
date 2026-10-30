# 소담 본사 UI

참조: 사용자가 제공한 `sodam-riverpod-lazy-loading (1).zip` 안의
`flutter_app/lib/core/theme.dart`, `flutter_app/lib/views/staff/shell.dart`.
참조 코드의 모스 그린·크림색, 카드, 업무 그룹 메뉴를 현재 업무 화면에 맞춰 재구성했다.
압축파일의 SQL, 서버, 기능 코드는 프로젝트에 복사하지 않았다.

## 실행

```powershell
cd C:\Seong\skin_project\frontend
flutter run -d chrome -t lib/main_sodam.dart
```

기존 서버를 실행하고 기존 ADMIN 또는 STAFF 계정으로 로그인한다.
기존 `lib/main.dart` 실행은 종전 화면을 유지한다.
추가한 진입점은 이미지 처리를 기존 서버 API에 위임하므로 Firebase SDK 초기화를 요구하지 않는다.
서버의 Storage 권한 설정은 기존과 동일하게 필요하다.

## 구성

- `lib/main_sodam.dart`: 기존 로그인 화면과 인증 서비스를 연결하는 선택적 진입점.
- `lib/design/sodam_theme.dart`: 참조 색상, 버튼, 입력란, 카드, 표와 메뉴 스타일.
- `lib/design/sodam_shell.dart`: 본사 사이드바, 반응형 드로어, 직원·관리자 대시보드.
- 기존 업무 화면은 수정 없이 재사용한다. 개별 화면에 명시된 색상이나 배치는 그대로 남는다.
- ADMIN은 품의·발주·발주처 메뉴와 실제 조회값 기반 현황 카드를 본다.
- STAFF는 기존 권한 범위의 재고·입고·출고·주문·배송·반품 메뉴를 본다.
- 960px 미만은 메뉴를 드로어로 전환하고 대시보드 카드를 세로로 배치한다.
- 새 로그인마다 별도의 Riverpod 컨테이너와 내비게이터를 생성하여 상세 화면도 같은 세션을 사용한다.

기존 추적 코드, pubspec, API, DB 스키마는 수정하지 않았다.
참조에만 있는 통계·정책·직원 등록 등의 미구현 업무는 메뉴로 추가하지 않았다.

## 미리보기 및 검증

`flutter test test/sodam_design_test.dart`는 현재 Flutter 위젯을 직접 렌더링하여
`output/sodam-design/`에 관리자·직원 데스크톱/모바일 이미지 4개를 생성한다.
이미지의 현황 수치는 테스트용 0건이며 실데이터가 아니다.
Windows에서는 설치된 맑은 고딕으로 미리보기를 렌더링한다.

권한별 메뉴, 기존 재고 화면 진입, 상품 등록 버튼 권한, 새 진입점의 로그인·로그아웃,
상세 화면 세션 유지, 모바일/데스크톱 오버플로를 검증했다.
