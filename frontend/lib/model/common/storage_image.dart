class StorageImage {
  const StorageImage({
    required this.bucket,
    required this.objectName,
    this.version,
  });
  final String bucket;
  final String objectName;
  final String? version;

  String get name => objectName.split('/').last;
  String get title => name
      .replaceFirst(
        RegExp(r'\.(png|jpe?g|webp|gif)$', caseSensitive: false),
        '',
      )
      .trim();
  // Firebase는 파일명의 '+'가 인코딩되지 않으면 공백으로 해석해 404를 반환한다.
  Uri get downloadUri => Uri.parse(
    'https://firebasestorage.googleapis.com/v0/b/${Uri.encodeComponent(bucket)}/o/${Uri.encodeComponent(objectName)}?alt=media${version == null ? '' : '&v=${Uri.encodeComponent(version!)}'}',
  );
}

class ProductImageMatch {
  const ProductImageMatch(this.image, {this.isRepresentative = false});
  final StorageImage image;
  final bool isRepresentative;
}

// 변경 내용(2026-10-30): 고객·관리자가 같은 Storage 이미지 모델과 URL 인코딩을 사용한다.
