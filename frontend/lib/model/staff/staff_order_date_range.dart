/// 사용자 입력의 정확한 단위(연/월/일/시/분)를 보존합니다.
/// 백엔드는 마지막 입력 단위의 전체 기간을 종료 범위에 포함합니다.
typedef StaffOrderDateKey = (int?, int?, int?, int?, int?);

class StaffOrderDateParts {
  const StaffOrderDateParts({this.year, this.month, this.day, this.hour, this.minute});

  final int? year;
  final int? month;
  final int? day;
  final int? hour;
  final int? minute;

  StaffOrderDateKey get key => (year, month, day, hour, minute);

  factory StaffOrderDateParts.fromKey(StaffOrderDateKey key) => StaffOrderDateParts(
    year: key.$1, month: key.$2, day: key.$3, hour: key.$4, minute: key.$5,
  );

  Map<String, String> toQuery(String prefix) => {
    if (year != null) '${prefix}_year': '$year',
    if (month != null) '${prefix}_month': '$month',
    if (day != null) '${prefix}_day': '$day',
    if (hour != null) '${prefix}_hour': '$hour',
    if (minute != null) '${prefix}_minute': '$minute',
  };

  String get label {
    final b = StringBuffer('${year ?? ''}');
    if (month != null) b.write('-${_two(month!)}');
    if (day != null) b.write('-${_two(day!)}');
    if (hour != null) b.write(' ${_two(hour!)}');
    if (minute != null) b.write(':${_two(minute!)}');
    return b.toString();
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static StaffOrderDateParts? parseFields(List<String> fields, String label) {
    if (fields.length != 5) throw ArgumentError('입력 단위는 5개여야 합니다.');
    final values = <int?>[];
    for (final value in fields) {
      final clean = value.trim();
      if (clean.isNotEmpty && !RegExp(r'^\d+$').hasMatch(clean)) {
        throw FormatException('$label: 숫자만 입력할 수 있습니다.');
      }
      values.add(clean.isEmpty ? null : int.tryParse(clean));
      if (clean.isNotEmpty && values.last == null) {
        throw FormatException('$label: 너무 큰 숫자입니다.');
      }
    }
    if (values.every((part) => part == null)) return null;
    var seenEmpty = false;
    for (final part in values) {
      if (part == null) seenEmpty = true;
      if (part != null && seenEmpty) {
        throw FormatException('$label: 연 → 월 → 일 → 시 → 분 순으로 입력하세요.');
      }
    }
    final y = values[0]!;
    final m = values[1];
    final d = values[2];
    final h = values[3];
    final min = values[4];
    if (y < 1 || y > 9998) throw FormatException('$label: 연도 범위는 1~9998입니다.');
    if (m != null && (m < 1 || m > 12)) throw FormatException('$label: 월은 1~12입니다.');
    if (d != null) {
      final maxDay = DateTime.utc(y, m! + 1, 0).day;
      if (d < 1 || d > maxDay) throw FormatException('$label: 존재하지 않는 날짜입니다.');
    }
    if (h != null && (h < 0 || h > 23)) throw FormatException('$label: 시는 0~23입니다.');
    if (min != null && (min < 0 || min > 59)) throw FormatException('$label: 분은 0~59입니다.');
    return StaffOrderDateParts(year: y, month: m, day: d, hour: h, minute: min);
  }

  DateTime get beginUtc => DateTime.utc(year!, month ?? 1, day ?? 1, hour ?? 0, minute ?? 0);

  DateTime get endExclusiveUtc {
    if (month == null) return DateTime.utc(year! + 1);
    if (day == null) return DateTime.utc(year!, month! + 1);
    if (hour == null) return DateTime.utc(year!, month!, day! + 1);
    if (minute == null) return DateTime.utc(year!, month!, day!, hour! + 1);
    return DateTime.utc(year!, month!, day!, hour!, minute! + 1);
  }

  static void validateRange(StaffOrderDateParts? start, StaffOrderDateParts? end) {
    if (start != null && end != null &&
        !start.beginUtc.isBefore(end.endExclusiveUtc)) {
      throw const FormatException('시작 시각은 종료 범위의 끝보다 빨라야 합니다.');
    }
  }
}
