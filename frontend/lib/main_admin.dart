import 'app/bootstrap.dart';
import 'app/admin_app.dart';
export 'app/admin_app.dart';

Future<void> main() => launchApp(const AdminApp());

// 관리자·직원 전용 실행: flutter run -t lib/main_admin.dart
