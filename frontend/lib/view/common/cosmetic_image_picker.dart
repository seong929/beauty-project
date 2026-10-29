import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'cosmetic_image.dart';

class SelectedCosmeticImage {
  const SelectedCosmeticImage(this.bytes, this.filename);
  final Uint8List bytes;
  final String filename;
}

final imagePickerProvider = Provider<ImagePicker>((ref) => ImagePicker());

class CosmeticImagePicker extends ConsumerWidget {
  const CosmeticImagePicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.cosmeticId,
    this.enabled = true,
  });
  final SelectedCosmeticImage? selected;
  final ValueChanged<SelectedCosmeticImage?> onChanged;
  final String? cosmeticId;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (selected != null)
        Image.memory(
          selected!.bytes,
          height: 160,
          width: 160,
          fit: BoxFit.contain,
        )
      else
        CosmeticImage(
          cosmeticIds: cosmeticId == null ? const [] : [cosmeticId!],
          size: 160,
        ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('이미지 선택'),
            onPressed: !enabled
                ? null
                : () async {
                    try {
                      final file = await ref
                          .read(imagePickerProvider)
                          .pickImage(source: ImageSource.gallery);
                      if (file == null) return;
                      final bytes = await file.readAsBytes();
                      if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
                        throw Exception('10MB 이하의 이미지를 선택해 주세요.');
                      }
                      if (!RegExp(
                        r'\.(png|jpe?g|webp)$',
                        caseSensitive: false,
                      ).hasMatch(file.name)) {
                        throw Exception('PNG, JPG 또는 WebP 이미지를 선택해 주세요.');
                      }
                      if (context.mounted) {
                        onChanged(SelectedCosmeticImage(bytes, file.name));
                      }
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              error.toString().replaceFirst('Exception: ', ''),
                            ),
                          ),
                        );
                      }
                    }
                  },
          ),
          if (selected != null)
            TextButton(
              onPressed: !enabled ? null : () => onChanged(null),
              child: const Text('선택 취소'),
            ),
        ],
      ),
      const Text('PNG · JPG · WebP, 최대 10MB'),
      const SizedBox(height: 16),
    ],
  );
}
