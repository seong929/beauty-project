import 'app/bootstrap.dart';
import 'app/customer_app.dart';
export 'app/customer_app.dart';

Future<void> main() => launchApp(const CustomerApp());

// 고객 전용 실행: flutter run -t lib/main_customer.dart
