# 화장품 이미지

DB 스키마는 변경하지 않는다. 이미지는 Firebase Storage의
`cosmetics-store-image-storage.firebasestorage.app` 버킷에
`cosmetics/{cosmetic_id}/image` 경로로 저장한다.

- 상품 등록 화면에서 이미지를 선택하고 등록한다. 상품 생성 후 이미지 업로드만 실패하면 같은 ID로 재시도한다.
- 관리자 재고 관리 → 옵션 상세에서 이미지를 선택하고 변경사항을 저장한다.
- 목록 대표 이미지는 옵션 조회 순서대로 검사한다. 이미지 없음, 조회 오류, 실제 이미지 로딩 실패 시 다음 옵션을 시도한다.
- Flutter의 `image_picker`와 서버의 `google-cloud-storage`, `Pillow`, `python-multipart` 의존성을 사용한다. 업로드는 관리자 인증 API를 거친다.

## 서버 인증 및 기존 이미지 등록

Firebase 앱 초기화와 별도로 백엔드가 버킷을 읽고 쓸 수 있는 Google 인증이 필요하다.
운영 서버에는 해당 버킷의 객체 읽기·쓰기 권한을 가진 서비스 계정을 연결하거나
`GOOGLE_APPLICATION_CREDENTIALS`에 서비스 계정 JSON의 로컬 경로를 설정한다.
로컬 개발에서는 기존 Firebase CLI 로그인도 사용한다.

```powershell
cd backend
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe seed_cosmetic_images.py C:/Users/hyuk/Downloads/Downloads.zip --apply
```

이 명령은 기존 이미지를 덮어쓰지 않고 DB는 조회만 한다.
매칭 결과는 `database/cosmetic_image_mapping.json`에 기록한다.

2026-10-29 검증: 현재 DB 9개 옵션 중 토너 2개와 바디로션 1개를 매칭했다.
현재 CLI 인증 계정이 버킷 객체 읽기에서 403을 반환하여 이번 등록 시도는 3개 모두 실패했다.
나머지 6개는 압축파일에 대응하는 틴트·샴푸·선크림 사진이 없거나 테스트 상품이다.
이전 보고서의 업로드 표시는 이번 세션에서 확인되지 않았으며 현재 보고서는 이번 시도 결과다.

검증: Flutter 전체 테스트 21개, 백엔드 이미지·상품 상세·카탈로그·관리자 권한 테스트 19개 통과.
백엔드 전체의 기존 고객·리뷰 테스트에서는 실패 45건(서브테스트 포함), 오류 6건이 남아 있다.
