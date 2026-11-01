// 기능: 고객용 공용 Firebase 이미지 타입 연결.
// 데이터 모델 계층: Riverpod 의존성을 넣지 않고 데이터와 변환·계산만 제공한다.

import '../common/storage_image.dart';
export '../common/storage_image.dart';

// 기존 고객 코드의 타입 이름을 유지하며 관리자와 동일한 모델을 사용한다.
typedef CustomerStorageImage = StorageImage;
typedef CustomerProductImage = ProductImageMatch;
