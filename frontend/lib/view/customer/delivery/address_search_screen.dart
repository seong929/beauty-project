import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

class CustomerAddressSearchScreen extends StatefulWidget {
  const CustomerAddressSearchScreen({super.key});

  @override
  State<CustomerAddressSearchScreen> createState() =>
      _CustomerAddressSearchScreenState();
}

class _CustomerAddressSearchScreenState
    extends State<CustomerAddressSearchScreen> {
  WebViewController? _controller;
  Timer? _timeout;
  bool _loading = true;
  bool _returned = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb &&
        const {
          TargetPlatform.android,
          TargetPlatform.iOS,
          TargetPlatform.macOS,
        }.contains(defaultTargetPlatform)) {
      _initialize();
    } else {
      _loading = false;
      _error = '이 기기에서는 주소 검색을 지원하지 않습니다. 이전 화면에서 주소를 직접 입력해 주세요.';
    }
  }

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
            setState(() => _loading = false);
            return;
          }
          try {
            final result = PostalAddress.fromMessage(message.message);
            _returned = true;
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
    setState(() {
      _loading = true;
      _error = null;
    });
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

  void _fail(String message) {
    if (!mounted || _returned) return;
    _timeout?.cancel();
    setState(() {
      _loading = false;
      _error = message;
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
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
