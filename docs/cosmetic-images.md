# 화장품 이미지

DB 스키마는 변경하지 않는다. 이미지는 Firebase Storage의
`beauty-skin-20e94.firebasestorage.app` 버킷에
`cosmetics/{cosmetic_id}/image` 경로로 저장한다.

- 상품 등록 화면에서 이미지를 선택하고 등록한다. 상품 생성 후 이미지 업로드만 실패하면 같은 ID로 재시도한다.
- 관리자 재고 관리 → 옵션 상세에서 이미지를 선택하고 변경사항을 저장한다.
- 고객·관리자 공용 Storage 목록에서 상품번호 경로, 상품명 일치 사진, 같은 종류의 대표 사진 순서로 찾는다. 관리자에서는 공개 이미지가 없거나 깨졌을 때 기존 직원 인증 이미지 API를 확인하고 다음 옵션을 시도한다.
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

2026-10-30: 고객·관리자 Firebase 대상을 같은 `beauty-skin-20e94` 프로젝트로 맞췄다. 공개 목록의 사진 30개와 백엔드 자격증명을 통한 기존 이미지 읽기를 확인했다. 이번 변경에서 원격 이미지 업로드·덮어쓰기는 실행하지 않았다. 이전 버킷에 대한 보고서와 권한 오류는 새 버킷의 현재 상태를 의미하지 않는다. 구체적인 연결 기준과 실행 방법은 [고객·관리자 이미지 문서](customer-firebase-images.md)를 참고한다.

검증: Flutter 전체 테스트 200개, 백엔드 이미지 권한·파일 검사·업로드 보호 테스트 3개 통과. 실제 업로드 권한은 업로드 시 백엔드 인증으로 확인한다.
