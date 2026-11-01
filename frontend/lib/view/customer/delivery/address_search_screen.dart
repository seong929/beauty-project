// 기능: 우편번호 WebView 연결·주소 결과·오류·재시도.
// 표시 계층: ref.watch로 상태를 구독하고 사용자 동작은 Notifier·서비스에 전달한다.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:beauty_project/vm/customer/state/customer_screen_handler.dart';
import 'package:webview_flutter/webview_flutter.dart';

class PostalAddress {
  const PostalAddress({required this.zonecode, required this.address});
  final String zonecode;
  final String address;

  factory PostalAddress.fromMessage(String message) {
    final data = jsonDecode(message);
    if (data is! Map ||
        data['zonecode'] is! String ||
        data['address'] is! String ||
        !RegExp(r'^\d{5}$').hasMatch(data['zonecode'] as String) ||
        (data['address'] as String).trim().isEmpty ||
        (data['address'] as String).length > 480) {
      throw const FormatException('주소 검색 응답 오류');
    }
    return PostalAddress(
      zonecode: data['zonecode'],
      address: (data['address'] as String).trim(),
    );
  }

  String get formatted => '($zonecode) $address';
}

// 테스트에서는 검색 결과를 주입하고 실제 앱에서는 주소 검색 화면을 연다.
final addressSearchLauncherProvider =
    Provider<Future<PostalAddress?> Function(BuildContext)>(
      (ref) =>
          (context) => Navigator.of(context).push<PostalAddress>(
            MaterialPageRoute(
              builder: (_) => const CustomerAddressSearchScreen(),
            ),
          ),
    );

class CustomerAddressSearchScreen extends ConsumerStatefulWidget {
  const CustomerAddressSearchScreen({super.key});

  @override
  ConsumerState<CustomerAddressSearchScreen> createState() =>
      _CustomerAddressSearchScreenState();
}

class _CustomerAddressSearchScreenState
    extends ConsumerState<CustomerAddressSearchScreen> {
  WebViewController? _controller;
  Timer? _timeout;
  late final _supported =
      !kIsWeb &&
      const {
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
      }.contains(defaultTargetPlatform);
  late final _postalProvider = customerPostalSearchProvider((
    screen: this,
    supported: _supported,
  ));
  CustomerPostalSearchHandler get _postal => ref.read(_postalProvider.notifier);
  bool get _loading => ref.read(_postalProvider).loading;
  bool get _returned => ref.read(_postalProvider).returned;
  String? get _error => ref.read(_postalProvider).error;

  @override
  void initState() {
    super.initState();
    if (_supported) {
      _initialize();
    }
  }

  /// Function: 주소 검색 WebView를 준비하고 주소 결과·오류 이벤트를 연결한다.
  Future<void> _initialize() async {
    try {
      final controller = WebViewController();
      _controller = controller;
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.addJavaScriptChannel(
        'onComplete',
        onMessageReceived: (message) {
          if (!mounted || _returned) return;
          if (message.message == 'ready') {
            _timeout?.cancel();
            _postal.ready();
            return;
          }
          try {
            final result = PostalAddress.fromMessage(message.message);
            _postal.returned();
            Navigator.of(context).pop(result);
          } on FormatException {
            _fail('주소를 불러오지 못했습니다. 다시 검색해 주세요.');
          }
        },
      );
      await controller.setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (error) {
            if (error.isForMainFrame == true) {
              _fail('주소 검색에 연결하지 못했습니다. 네트워크를 확인해 주세요.');
            }
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            return uri?.scheme == 'https' || request.url == 'about:blank'
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
        ),
      );
      if (!mounted) return;
      await _load();
    } catch (_) {
      _fail('주소 검색을 시작하지 못했습니다. 앱을 다시 실행해 주세요.');
    }
  }

  Future<void> _load() async {
    _timeout?.cancel();
    _postal.start();
    _timeout = Timer(
      const Duration(seconds: 20),
      () => _fail('주소 검색 연결이 지연되고 있습니다. 다시 시도해 주세요.'),
    );
    try {
      await _controller!.loadHtmlString(_html, baseUrl: 'https://localhost');
    } catch (_) {
      _fail('주소 검색에 연결하지 못했습니다. 다시 시도해 주세요.');
    }
  }

  /// Function: 현재 화면이 유효한 경우 주소 검색 오류를 상태에 표시한다.
  void _fail(String message) {
    if (!mounted || _returned) return;
    _timeout?.cancel();
    _postal.fail(message);
  }

  /// Function: 입력·포커스·스크롤 등 화면이 소유한 자원을 해제한다. Provider는 autoDispose 규칙을 따른다.
  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(_postalProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('배송지 주소 검색')),
      body: Stack(
        children: [
          if (_controller != null) WebViewWidget(controller: _controller!),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              alignment: Alignment.center,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  if (_controller != null)
                    TextButton(onPressed: _load, child: const Text('다시 시도')),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// 첨부 예제의 Daum 우편번호 검색을 Riverpod 앱의 Navigator 결과로 반환한다.
const _html = '''<!DOCTYPE html><html lang="ko"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
<script src="https://t1.daumcdn.net/mapjsapi/bundle/postcode/prod/postcode.v2.js"></script>
</head><body style="margin:0;padding:0"><div id="layer" style="width:100%;height:100vh"></div>
<script>
try {
  new daum.Postcode({
    oncomplete: function(data) {
      var address = data.userSelectedType === 'R' ? data.roadAddress : data.jibunAddress;
      address = address || data.autoRoadAddress || data.autoJibunAddress || data.address;
      onComplete.postMessage(JSON.stringify({zonecode: data.zonecode, address: address}));
    },
    onresize: function() { onComplete.postMessage('ready'); },
    width:'100%',height:'100%'
  }).embed(document.getElementById('layer'));
} catch(e) { onComplete.postMessage('error'); }
</script></body></html>''';
