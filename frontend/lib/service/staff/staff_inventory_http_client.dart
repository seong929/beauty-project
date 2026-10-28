import 'package:http/http.dart' as http;
import 'staff_inventory_http_client_native.dart'
    if (dart.library.html) 'staff_inventory_http_client_web.dart' as platform;

http.Client createStaffInventoryHttpClient() => platform.createClient();
