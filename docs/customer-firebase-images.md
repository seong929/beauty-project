# 고객·관리자 Firebase 상품 이미지

고객·관리자 화면은 `beauty-skin-20e94.firebasestorage.app`에 업로드된 사진과 같은 상품 매칭 기준을 사용한다. 관리자 백엔드의 기존 다른 버킷 참조를 이 버킷으로 맞췄다. DB 상품번호·가격·재고·주문 정보는 유지한다.

- 버킷은 `frontend/lib/firebase_options.dart`의 현재 플랫폼 설정을 따른다. 필요하면 `--dart-define=FIREBASE_STORAGE_BUCKET=버킷명`으로 지정할 수 있다.
- `lib/model/common`, `service/common`, `vm/common`의 공용 모델·목록·매칭을 사용한다. 기존 고객 모듈은 같은 Provider를 재사용하는 호환 경로다.
- Firebase Storage 목록 API를 폴더·페이지 단위로 조회하고 PNG/JPG/WebP/GIF 및 상품번호 경로의 이미지만 표시한다. 관리자 업로드 경로인 `cosmetics/{cosmetic_id}/image`도 조회한다. 목록은 화면들이 공유하며 새로고침으로 재조회한다.

폴더와 파일이 분리되는 목록 응답은 [Firebase 공식 목록 API 문서](https://firebase.google.com/docs/storage/web/list-files)의 구조에 맞춰 처리한다.
- 관리자 업로드 성공 또는 새로고침 시 공용 목록과 이미지 캐시 URL 버전을 갱신한다. 다른 실행 중인 앱에서는 홈/재고/옵션 상세를 새로고침하면 교체한 이미지를 확인할 수 있다.
- 홈 상단은 최대 10개, 전체 보기는 조회된 모든 이미지(현재 30개)를 표시한다. 사진을 누르면 확대할 수 있다. 목록 오류·빈 목록·개별 이미지 실패를 구분한다.
- 파일명에는 한글·공백·`+`가 포함될 수 있어 각 객체 이름을 URL 인코딩한다. 특히 인코딩하지 않은 `+`는 실제 Firebase 요청에서 404를 반환하므로 `%2B`로 보낸다.
- 고객용 읽기는 공개 이미지 API를 사용한다. 직원 로그인 토큰, Firebase 관리 자격증명, 고객 정보는 보내지 않는다. 저장소 권한은 변경하지 않는다. 읽기 권한이 바뀌면 권한 안내와 재시도 버튼을 표시한다.

## 상품 이미지 연결

고객 `ProductPhoto`와 관리자 `CosmeticImage`가 같은 상품 이미지 Provider를 사용하므로 홈·검색·상세·장바구니·결제·구매 내역·관리자 재고/옵션 상세에 같은 기준을 적용한다.

1. `cosmetics/{cosmetic_id}/image` 객체를 우선 사용한다.
2. 상품명과 이미지 파일명(확장자·공백 제외)이 정확히 일치하면 해당 사진을 사용한다.
3. 사용자가 허용한 같은 종류의 대표 사진을 연결하며 `대표 이미지` 문구를 표시한다.

기존 DB 상품을 사용하는 검색·상세·장바구니 등에서는 수분 진정 토너 200ml·400ml 옵션에 `소나무 진정 시카 토너.png`, 리페어 바디로션에 `세라마이드 아토 로션.png`를 대표 사진으로 연결한다. 대응 사진이 없는 선크림·틴트·샴푸·테스트 상품에는 관련 없는 사진을 배정하지 않는다.

## 홈·검색 상품과 상세

홈과 검색 상품 카드는 Firebase에 실제로 올라온 스킨·로션·크림 사진을 기준으로 구성하며 같은 목록·필터·카드를 사용한다. 기존 DB의 틴트·샴푸·선크림·테스트 상품은 이 영역에 포함하지 않는다. `model/customer/storage_product.dart`, `vm/customer/storage_product_handler.dart`, `view/customer/home/storage_product_tile.dart`에서 표시 모델·조회/필터·카드를 나눈다.

- 현재 사진 30개의 파일명에서 상품명과 스킨/로션/크림 유형을 읽어 표시한다.
- 사진만 있는 항목에는 스킨 200ml, 로션 150ml, 크림 50ml와 상품명에 따라 일정하게 유지되는 임시 가격을 표시하고 `임시 가격·용량` 문구로 구분한다. 재고를 만들거나 실제 DB 판매 상품으로 취급하지 않는다.
- 홈·검색의 카드를 누르면 같은 상품 상세 페이지로 이동한다. Firebase 원본 사진·용량·가격이 그대로 전달된다. 임시 상품에는 판매 준비 상태를 표시하고 장바구니·구매 버튼을 비활성화한다.
- DB 상품번호 경로나 정확한 상품명으로 연결된 항목에는 실제 DB 가격·용량을 표시하고 기존 상품 상세로 이동한다. 같은 종류의 대표 사진이라는 이유만으로 판매 상품을 연결하지 않는다.
- 카테고리 탭·검색어·정렬·가격 필터가 홈과 검색에 적용되며, 판매 상품만 보기에서는 실제 재고가 있는 연결 상품만 남는다. 홈 전체 보기는 동일한 상품 검색 목록을 연다. 상단 사진 갤러리의 전체 보기는 확대 가능한 사진 목록을 유지한다.
- DB 조회가 실패해도 Firebase 사진 목록은 표시한다. 결제·재고 검증은 기존 DB 카탈로그를 계속 사용한다.

하단 탭의 검색·장바구니·내 정보 이동은 `view/customer/customer_navigation.dart`의 공통 함수로 메인과 선택한 탭만 남긴다. 상단 뒤로가기와 Android 뒤로가기 모두 이전 탭 대신 메인으로 돌아간다. 상품 상세·정보 수정 등 탭 내부 화면은 일반적인 뒤로가기를 유지한다.

고객과 관리자는 `view/common/storage_photo.dart`의 동일한 공개 이미지 로더와 표시 위젯을 사용한다. Firebase 목록 조회는 성공해도 개별 파일 응답에 CORS 헤더가 없으면 Chrome의 이미지 바이트 조회가 차단될 수 있다. 웹 로더는 `WebHtmlElementStrategy.fallback`으로 이 경우 HTML 이미지 표시로 전환한다. Android는 기존 네트워크 이미지 로딩 방식을 유지한다. 서버의 조회 성공 로그만으로 브라우저 이미지 표시 성공을 판정하지 않는다.

이미지 업로드는 기존 관리자 권한, 파일 형식/크기 검사, 덮어쓰기 보호를 유지한다. 서버 기본 설정은 `FIREBASE_STORAGE_BUCKET=beauty-skin-20e94.firebasestorage.app`, `FIREBASE_STORAGE_PROJECT=beauty-skin-20e94`이며 환경변수로 변경할 수 있다. 별도 버킷으로 변경한다면 프런트엔드 설정도 동일하게 맞춰야 한다.

## 로그인 실행 분리

`frontend` 폴더에서 실행한다. 기본 `flutter run`은 고객 앱만 실행한다.

```powershell
# 고객 로그인 → 고객 홈
flutter run -t lib/main_customer.dart
# 관리자·직원 로그인 → 관리 화면
flutter run -t lib/main_admin.dart
# 기존 관리자 디자인 전용 진입점
flutter run -t lib/main_sodam.dart
# 기존 배송업체 로그인
flutter run -t lib/main_delivery.dart
```

VS Code 실행 목록에도 `소담 고객`, `소담 관리자`, `소담 배송업체`를 추가했다. 각 앱은 자체 로그인 화면만 제공하며 로그인 유형 선택 화면을 거치지 않는다. 실행 진입점을 바꿀 때는 기존 디버깅을 중지한 뒤 해당 구성을 새로 실행한다. Firebase 프로젝트를 복제하거나 별도 기본 앱을 중복 초기화하지 않는다.

## 검증

`flutter test --platform chrome --dart-define=RUN_FIREBASE_WEB_TEST=true test/storage_photo_web_test.dart`는 실제 Firebase 파일을 읽어 HTML 이미지 표시와 관리자 위젯 렌더링까지 검증한다. 기본 테스트에서는 외부 네트워크 의존성을 피하기 위해 제외된다. Windows Flutter 3.44.6의 테스트 서버가 `/canvaskit/` 요청에 404를 반환하는 경우에는 CanvasKit 테스트 자산 제공 문제를 먼저 해결해야 한다. 이번 Chrome 검증은 설치된 SDK의 CanvasKit 파일을 테스트 브라우저에 제공해 통과했으며 SDK와 저장소 권한은 변경하지 않았다.

2026-10-30: 실제 버킷의 PNG 30개를 다운로드해 PNG 서명·청크 CRC·압축 데이터를 검증했다. 로컬 검증 파일은 무시되는 `frontend/build/firebase_preview/`에만 저장한다. 자동 테스트는 페이지 처리, 한글·공백·특수문자 URL, 권한·잘못된 응답, 정확/대표 매칭, 상단 10개·전체 30개·확대, 재시도·깨진 사진, 상품번호·가격 유지 동작을 검증한다.
