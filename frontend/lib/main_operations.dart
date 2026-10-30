import 'app/bootstrap.dart';
import 'app/operations_app.dart';

/// ADMIN only. Existing main_admin/main_sodam/main.dart entry points are intact.
Future<void> main() => launchApp(const OperationsApp());
