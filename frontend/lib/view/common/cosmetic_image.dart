import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../vm/admin/management_vm.dart';
import '../../vm/common/storage_image_handler.dart';

final cosmeticImageLoaderProvider =
    Provider<ImageProvider<Object> Function(String)>(
      (ref) =>
          (url) => NetworkImage(url),
    );

/// 각 옵션에서 공용 Firebase 사진을 우선 표시하고 인증 이미지 API도 지원한다.
class CosmeticImage extends ConsumerStatefulWidget {
  const CosmeticImage({
    super.key,
    required this.cosmeticIds,
    this.cosmeticName = '',
    this.size = 64,
  });
  final List<String> cosmeticIds;
  final String cosmeticName;
  final double size;
  @override
  ConsumerState<CosmeticImage> createState() => _CosmeticImageState();
}

class _CosmeticImageState extends ConsumerState<CosmeticImage> {
  int index = 0;
  int revision = 0;
  bool _usingBackend = false;
  bool _scheduled = false;

  void _reset() {
    revision++;
    index = 0;
    _usingBackend = false;
    _scheduled = false;
  }

  @override
  void didUpdateWidget(covariant CosmeticImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.cosmeticIds, widget.cosmeticIds) ||
        oldWidget.cosmeticName != widget.cosmeticName) {
      _reset();
    }
  }

  void _advance({bool tryBackend = false}) {
    if (_scheduled) return;
    _scheduled = true;
    final previous = index;
    final previousRevision = revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || revision != previousRevision || index != previous) return;
      setState(() {
        _scheduled = false;
        if (tryBackend) {
          _usingBackend = true;
        } else {
          index++;
          _usingBackend = false;
        }
      });
    });
  }

  Widget _placeholder() => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Center(child: Icon(Icons.image_outlined, size: widget.size / 3)),
  );

  Widget _image(String url, {bool representative = false}) => Stack(
    fit: StackFit.expand,
    children: [
      Image(
        image: ref.read(cosmeticImageLoaderProvider)(url),
        key: ValueKey(url),
        fit: BoxFit.contain,
        semanticLabel: representative
            ? '${widget.cosmeticName} 대표 이미지'
            : widget.cosmeticName,
        errorBuilder: (_, _, _) {
          _advance(tryBackend: !_usingBackend);
          return _placeholder();
        },
      ),
      if (representative)
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            color: const Color(0xE6FFFFFF),
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            child: const Text(
              '대표 이미지',
              style: TextStyle(fontSize: 8, color: Colors.grey),
            ),
          ),
        ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    ref.listen(cosmeticImagesRevisionProvider, (_, _) => setState(_reset));
    ref.listen(storageImagesProvider, (previous, next) {
      if (next.hasValue &&
          !next.isLoading &&
          !identical(previous?.value, next.value)) {
        setState(_reset);
      }
    });
    final id = index < widget.cosmeticIds.length
        ? widget.cosmeticIds[index]
        : null;
    final Widget image;
    if (id == null) {
      image = _placeholder();
    } else if (_usingBackend) {
      image = ref
          .watch(cosmeticImageProvider(id))
          .when(
            loading: _placeholder,
            error: (_, _) {
              _advance();
              return _placeholder();
            },
            data: (url) {
              if (url == null) {
                _advance();
                return _placeholder();
              }
              return _image(url);
            },
          );
    } else {
      image = ref
          .watch(
            productStorageImageProvider((id: id, name: widget.cosmeticName)),
          )
          .when(
            loading: _placeholder,
            error: (_, _) {
              _advance(tryBackend: true);
              return _placeholder();
            },
            data: (match) {
              if (match == null) {
                _advance(tryBackend: true);
                return _placeholder();
              }
              return _image(
                match.image.downloadUri.toString(),
                representative: match.isRepresentative,
              );
            },
          );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(width: widget.size, height: widget.size, child: image),
    );
  }
}

// 변경 내용(2026-10-30): 고객과 같은 버킷·상품명/상품번호·대표 이미지 연결을 사용한다.
// 공개 사진을 사용할 수 없는 경우 직원 인증 이미지 API로 확인한 뒤 다음 옵션을 검사한다.
