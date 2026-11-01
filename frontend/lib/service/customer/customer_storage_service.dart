// 기능: 공용 Firebase Storage 조회 서비스 재사용.
// 통신 계층: 요청·응답 검증을 담당하고 로딩·성공·실패 표시는 VM의 AsyncValue에 맡긴다.

import '../common/storage_service.dart';
export '../common/storage_service.dart';

// 기존 고객 서비스 호출 이름을 유지한다.
typedef CustomerStorageService = StorageService;
