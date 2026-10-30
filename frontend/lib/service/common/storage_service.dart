import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:beauty_project/model/common/storage_image.dart';

class StorageImageException implements Exception {
  const StorageImageException(this.message);
  final String message;
  @override
  String toString() => message;
}

class StorageService {
  const StorageService({required this.client, required this.bucket});
  final http.Client client;
  final String bucket;

  // Firebase 콘솔 주소 대신 공개 읽기가 가능한 Storage REST API를 사용한다.
  // 인증 토큰과 DB 상품 정보는 이 요청에 전달하지 않는다.
  Future<List<StorageImage>> fetchImages() async {
    try {
      final images = <String, StorageImage>{};
      final prefixes = <String>[''];
      final seenPrefixes = <String>{''};
      final version = DateTime.now().microsecondsSinceEpoch.toString();
      for (var index = 0; index < prefixes.length; index++) {
        final prefix = prefixes[index];
        final visited = <String>{};
        String? next;
        do {
          final uri = Uri(
            scheme: 'https',
            host: 'firebasestorage.googleapis.com',
            pathSegments: ['v0', 'b', bucket, 'o'],
            queryParameters: {
              'maxResults': '1000',
              'delimiter': '/',
              if (prefix.isNotEmpty) 'prefix': prefix,
              'pageToken': ?next,
            },
          );
          final response = await client
              .get(uri)
              .timeout(const Duration(seconds: 15));
          if (response.statusCode == 401 || response.statusCode == 403) {
            throw const StorageImageException('Firebase 이미지 읽기 권한을 확인해 주세요.');
          }
          if (response.statusCode != 200) {
            throw const StorageImageException('상품 이미지를 불러오지 못했어요. 다시 시도해 주세요.');
          }
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          if (data is! Map<String, dynamic>) throw const FormatException();
          final rows = data['items'] ?? const [];
          if (rows is! List) throw const FormatException();
          for (final row in rows) {
            if (row is! Map ||
                row['name'] is! String ||
                (row['name'] as String).isEmpty) {
              throw const FormatException();
            }
            final name = row['name'] as String;
            if (RegExp(
              r'\.(png|jpe?g|webp|gif)$|/image$',
              caseSensitive: false,
            ).hasMatch(name)) {
              images[name] = StorageImage(
                bucket: bucket,
                objectName: name,
                version: version,
              );
            }
          }
          final folders = data['prefixes'] ?? const [];
          if (folders is! List) throw const FormatException();
          for (final folder in folders) {
            if (folder is! String ||
                folder.isEmpty ||
                !folder.endsWith('/') ||
                !folder.startsWith(prefix)) {
              throw const FormatException();
            }
            if (seenPrefixes.add(folder)) prefixes.add(folder);
          }
          final token = data['nextPageToken'];
          if (token != null && token is! String) throw const FormatException();
          next = token is String && token.isNotEmpty ? token : null;
          if (next != null && !visited.add(next)) throw const FormatException();
        } while (next != null);
      }
      return List.unmodifiable(
        images.values.toList()
          ..sort((a, b) => a.objectName.compareTo(b.objectName)),
      );
    } on TimeoutException {
      throw const StorageImageException('이미지를 불러오는 시간이 초과됐어요. 다시 시도해 주세요.');
    } on http.ClientException {
      throw const StorageImageException('네트워크 연결을 확인하고 이미지를 다시 불러와 주세요.');
    } on FormatException {
      throw const StorageImageException('Firebase 이미지 목록을 확인할 수 없어요.');
    }
  }
}

// 변경 내용(2026-10-30): 공개 Storage 조회를 공유하며 직원 인증 토큰을 Firebase에 보내지 않는다.
// 관리자 업로드 폴더도 순회하고 재조회 시 이미지 URL 버전을 바꿔 교체된 사진을 반영한다.
