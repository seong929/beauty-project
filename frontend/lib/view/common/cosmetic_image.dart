import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../vm/admin/management_vm.dart';

final cosmeticImageLoaderProvider =
    Provider<ImageProvider<Object> Function(String)>(
      (ref) =>
          (url) => NetworkImage(url),
    );

/// Uses option ordering and advances only when metadata or the actual image fails.
class CosmeticImage extends ConsumerStatefulWidget {
  const CosmeticImage({super.key, required this.cosmeticIds, this.size = 64});
  final List<String> cosmeticIds;
  final double size;
  @override
  ConsumerState<CosmeticImage> createState() => _CosmeticImageState();
}

class _CosmeticImageState extends ConsumerState<CosmeticImage> {
  int index = 0;
  int? scheduledIndex;
  int revision = 0;
  @override
  void didUpdateWidget(covariant CosmeticImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.cosmeticIds, widget.cosmeticIds)) {
      revision++;
      index = 0;
      scheduledIndex = null;
    }
  }

  void _next() {
    if (scheduledIndex == index) return;
    scheduledIndex = index;
    final previous = index;
    final previousRevision = revision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && revision == previousRevision && index == previous) {
        setState(() => index++);
      }
    });
  }

  Widget _placeholder() => ColoredBox(
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Center(child: Icon(Icons.image_outlined, size: widget.size / 3)),
  );

  @override
  Widget build(BuildContext context) {
    ref.listen(cosmeticImagesRevisionProvider, (_, _) {
      setState(() {
        revision++;
        index = 0;
        scheduledIndex = null;
      });
    });
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: index >= widget.cosmeticIds.length
            ? _placeholder()
            : ref
                  .watch(cosmeticImageProvider(widget.cosmeticIds[index]))
                  .when(
                    loading: _placeholder,
                    error: (_, _) {
                      _next();
                      return _placeholder();
                    },
                    data: (url) {
                      if (url == null) {
                        _next();
                        return _placeholder();
                      }
                      return Image(
                        image: ref.read(cosmeticImageLoaderProvider)(url),
                        key: ValueKey(url),
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) {
                          _next();
                          return _placeholder();
                        },
                      );
                    },
                  ),
      ),
    );
  }
}
