// 기능: 고객별 저장 사진과 편집 화면의 임시 사진을 Riverpod로 관리한다.
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:beauty_project/service/customer/customer_profile_photo_service.dart';
import 'state/customer_screen_handler.dart';

final customerProfilePhotoServiceProvider = Provider(
  (ref) => CustomerProfilePhotoService(),
);

/// Function: 휴대폰 갤러리를 열고 선택한 사진의 크기와 디코딩을 확인한다.
/// 취소는 null이며, 권한·형식 오류는 호출 화면에서 안내한다.
final customerProfilePhotoPickerProvider =
    Provider<Future<Uint8List?> Function()>(
      (ref) => () async {
        final file = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 768,
          maxHeight: 768,
          imageQuality: 80,
          requestFullMetadata: false,
        );
        if (file == null) return null;
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty ||
            bytes.length > CustomerProfilePhotoService.maxBytes) {
          throw const FormatException('2MB 이하의 사진을 선택해 주세요.');
        }
        final codec = await ui.instantiateImageCodec(bytes);
        try {
          final frame = await codec.getNextFrame();
          frame.image.dispose();
        } finally {
          codec.dispose();
        }
        return bytes;
      },
    );

class CustomerProfilePhotoHandler extends AsyncNotifier<Uint8List?> {
  CustomerProfilePhotoHandler(this.customerId);
  final String customerId;

  @override
  Future<Uint8List?> build() =>
      ref.watch(customerProfilePhotoServiceProvider).load(customerId);

  /// Function: 기기에 저장한 뒤 구독 중인 마이페이지에도 새 사진을 반영한다.
  Future<void> save(Uint8List? bytes) async {
    await ref.read(customerProfilePhotoServiceProvider).save(customerId, bytes);
    if (ref.mounted) state = AsyncData(bytes);
  }
}

final customerProfilePhotoProvider = AsyncNotifierProvider.autoDispose
    .family<CustomerProfilePhotoHandler, Uint8List?, String>(
      CustomerProfilePhotoHandler.new,
      // 기기 저장소 오류는 자동 재시도로 폼을 잠그지 않고 사용자가 다시 조회한다.
      retry: (_, _) => null,
    );

// null: 변경 없음. (bytes: null): 기본 사진으로 변경. 저장 전 취소하면 자동 폐기한다.
typedef CustomerProfilePhotoDraft = ({Uint8List? bytes});
final customerProfilePhotoDraftProvider = NotifierProvider.autoDispose
    .family<
      CustomerChoiceHandler<CustomerProfilePhotoDraft?>,
      CustomerChoiceState<CustomerProfilePhotoDraft?>,
      Object
    >((_) => CustomerChoiceHandler(null));
