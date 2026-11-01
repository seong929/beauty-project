// 단일 파일 자동 품의 기능 검증 UI (Flutter Web / Android Emulator).
// 실행: flutter run -t lib/test_auto_approval.dart
// Android Emulator -> host PC: 10.0.2.2; real device needs host LAN IP.
// Uses existing http dependency. No login / no MVVM / no admin identity.
// 로컬 서버에서 테스트 API 플래그 없이 조회·수동 실행 가능. 외부 접속은 서버에서 차단한다.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const apiBaseUrl = 'http://127.0.0.1:8000';
const pageSize = 20;

void main() => runApp(const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AutoApprovalTestPage(),
    ));

class AutoApprovalTestPage extends StatefulWidget {
  const AutoApprovalTestPage({super.key});

  @override
  State<AutoApprovalTestPage> createState() => _AutoApprovalTestPageState();
}

class _AutoApprovalTestPageState extends State<AutoApprovalTestPage> {
  final http.Client _client = http.Client();
  bool _loading = true;
  bool _running = false;
  String? _error;
  int _page = 1;
  int _total = 0;
  List<Map<String, dynamic>> _approvals = [];
  Map<String, dynamic>? _schedule;
  Map<String, dynamic>? _lastResult;

  Uri _uri(String suffix, [Map<String, String>? query]) => Uri.parse(
        '$apiBaseUrl/system/automatic-approvals$suffix',
      ).replace(queryParameters: query);

  Future<dynamic> _request(String method, Uri uri) async {
    final http.Response response;
    try {
      final request = method == 'POST' ? _client.post(uri) : _client.get(uri);
      response = await request.timeout(const Duration(seconds: 30));
    } catch (e) {
      throw Exception('서버 연결 실패: $e\n확인: $apiBaseUrl 서버가 실행 중인지 확인해 주세요.');
    }
    dynamic body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      body = response.body;
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = body is Map ? (body['detail'] ?? body).toString() : '$body';
      if (response.statusCode == 404 && message.contains('테스트 API가 비활성화')) {
        throw Exception('이전 버전의 서버가 실행 중입니다. 백엔드를 재시작한 후 다시 시도해 주세요.');
      }
      throw Exception('HTTP ${response.statusCode}: $message');
    }
    return body;
  }

  Future<void> _reload({int? page}) async {
    final nextPage = page ?? _page;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // 품의 목록은 스케줄러 상태와 독립적으로 보여준다.
      // 구버전 서버의 /status 오류가 목록 전체를 가리는 현상 방지.
      final listResponse = await _request('GET', _uri('', {
        'page': '$nextPage',
        'count': '$pageSize',
      }));
      Map<String, dynamic> schedule;
      try {
        final statusResponse = await _request('GET', _uri('/status'));
        schedule = Map<String, dynamic>.from(statusResponse as Map);
      } catch (e) {
        schedule = {
          'scheduler_enabled': false,
          'state_error': '서버 자동 실행 상태 확인 불가: $e',
        };
      }
      if (!mounted) return;
      final list = Map<String, dynamic>.from(listResponse as Map);
      setState(() {
        _page = nextPage;
        _total = (list['total'] as num).toInt();
        _approvals = (list['items'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _schedule = schedule;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run() async {
    if (_running || _loading) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('자동 품의 수동 실행'),
        content: const Text('현재 재고 기준으로 실제 DB에 품의가 생성될 수 있습니다.\n'
            '이는 직원 결재가 아닌 시스템 자동 품의 테스트입니다. 실행할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('실행')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() {
      _running = true;
      _error = null;
    });
    try {
      final result = await _request('POST', _uri('/run'));
      if (!mounted) return;
      setState(() => _lastResult = Map<String, dynamic>.from(result as Map));
      await _reload(page: 1);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }

  String _fmt(dynamic value) {
    if (value == null) return '-';
    final raw = value.toString();
    return raw.replaceFirst('T', ' ');
  }

  Widget _buildStatus() {
    final last = _schedule?['last_run'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('서버 자동 실행', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('매일 ${_schedule?['scheduled_time'] ?? '03:00'} (한국 시간)'),
          Text('스케줄러: ${_schedule?['scheduler_enabled'] == true ? '활성' : '비활성'}'),
          Text('최근 실행일: ${_fmt(last is Map ? last['run_date'] : null)}'),
          Text('최근 실행 결과: ${_fmt(last is Map ? last['status'] : null)}'),
          if (last is Map)
            Text('검사 ${last['checked_count']}건 · 생성 ${last['created_count']}건 · '
                '오류 ${last['error_count']}건'),
          if (_schedule?['state_error'] != null)
            Text('${_schedule!['state_error']}',
                style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 8),
          const Text('일일 실행 이력은 서버 로컬 파일에 저장됩니다. DB 테이블 추가 불필요.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const Text('수동 테스트는 일일 스케줄 실행 기록을 변경하지 않습니다.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      ),
    );
  }

  String _resultLabel(String? result) {
    switch (result) {
      case 'CREATED': return '신규 품의 생성';
      case 'SUFFICIENT': return '재고 충분';
      case 'OPEN_APPROVAL_EXISTS': return '미완료 품의 존재 · 신규 생성 보류';
      case 'OPEN_PURCHASE_ORDER_EXISTS': return '입고 대기 발주 존재 · 신규 생성 보류';
      case 'INCONSISTENT_PURCHASE_ORDER': return '발주 상태·입고 수량 불일치 · 관리자 점검 필요';
      case 'NOT_ON_SALE': return '판매 중 아님';
      case 'SETTING_MISSING': return '최소/목표 재고 설정 누락';
      case 'INVALID_SETTING': return '최소/목표 재고 설정 오류';
      case 'ADMIN_MISSING': return '결재 담당 관리자 없음';
      case 'ERROR': return '처리 오류';
      default: return result ?? '알 수 없는 결과';
    }
  }

  Widget _buildResult() {
    final result = _lastResult;
    if (result == null) return const SizedBox.shrink();
    final results = result['results'];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('마지막 수동 실행 결과', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('검사 ${result['checked_count']}건 · 신규 품의 ${result['created_count']}건 '
              '· 오류 ${result['error_count']}건'),
          if (results is List)
            ...results.map((r) {
              if (r is! Map) return const SizedBox.shrink();
              final resultCode = r['result']?.toString();
              final orders = r['purchase_orders'];
              final approvals = r['pending_approvals'];
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${r['cosmetic_id']}: ${_resultLabel(resultCode)}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    if (r['requested_quantity'] != null)
                      Text('생성 수량 ${r['requested_quantity']}개',
                          style: const TextStyle(fontSize: 12)),
                    if (r['incoming_quantity'] != null)
                      Text('현재 ${r['current_quantity']}개 + 미입고 ${r['incoming_quantity']}개 '
                          '= 입고 예정 합계 ${r['projected_quantity']}개',
                          style: const TextStyle(fontSize: 12)),
                    if (r['projected_shortfall'] is num && r['projected_shortfall'] > 0)
                      Text('입고 예정 수량을 포함해도 목표까지 ${r['projected_shortfall']}개 부족 (자동 중복 품의 보류)',
                          style: const TextStyle(fontSize: 12, color: Colors.deepOrange)),
                    if (orders is List)
                      ...orders.whereType<Map>().map((po) => Text(
                          '발주 ${po['purchase_order_id']} · ${po['purchase_status']}'
                          ' · 주문 ${po['ordered_quantity']}개 / 입고 ${po['received_quantity']}개'
                          ' / 잔여 ${po['remaining_quantity']}개',
                          style: const TextStyle(fontSize: 12))),
                    if (approvals is List)
                      ...approvals.whereType<Map>().map((a) => Text(
                          '품의 ${a['approval_id']} · ${a['approval_status']}'
                          ' · 요청 ${a['requested_quantity']}개',
                          style: const TextStyle(fontSize: 12))),
                  ],
                ),
              );
            }),
        ]),
      ),
    );
  }

  Widget _buildApproval(Map<String, dynamic> a) {
    final status = '${a['approval_status'] ?? 'UNKNOWN'}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text('${a['cosmetic_name'] ?? a['cosmetic_id']}',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            Chip(label: Text(status)),
          ]),
          Text('품의 ID: ${a['approval_id']}', style: const TextStyle(fontSize: 12)),
          Text('품의 날짜: ${_fmt(a['requested_on'])}'),
          Text('현재 ${a['current_stock_snapshot']} → 목표 ${a['target_stock_snapshot']} '
              '· 요청 ${a['requested_quantity']}개'),
          if (a['approval_content'] != null) Text('${a['approval_content']}'),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxPage = _total == 0 ? 1 : (_total + pageSize - 1) ~/ pageSize;
    return Scaffold(
      appBar: AppBar(title: const Text('자동 품의 기능 테스트')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1050),
          child: RefreshIndicator(
            onRefresh: () => _reload(),
            child: ListView(padding: const EdgeInsets.all(16), children: [
              _buildStatus(),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: Text(_running ? '품의 처리 중…' : '자동 품의 지금 실행'),
                    onPressed: (_running || _loading) ? null : _run,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  tooltip: '목록 새로고침',
                  onPressed: _loading || _running ? null : () => _reload(),
                  icon: const Icon(Icons.refresh),
                ),
              ]),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: SelectableText(_error!, style: const TextStyle(color: Colors.red)),
                ),
              _buildResult(),
              const SizedBox(height: 12),
              Text('등록된 품의 ($_total건)',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              if (_loading) const LinearProgressIndicator(),
              if (!_loading && _approvals.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(25),
                  child: Center(child: Text('등록된 품의가 없습니다.')),
                ),
              ..._approvals.map(_buildApproval),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                  onPressed: (_loading || _page <= 1) ? null : () => _reload(page: _page - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('$_page / $maxPage'),
                IconButton(
                  onPressed: (_loading || _page >= maxPage)
                      ? null : () => _reload(page: _page + 1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}
