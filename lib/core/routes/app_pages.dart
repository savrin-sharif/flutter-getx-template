import 'package:get/get.dart';

import '../../shared/widgets/scaffold/app_scaffold.dart';
import 'app_routes.dart';

class AppPages {
  static final pages = [
    GetPage(name: AppRoutes.appScaffold, page: () => const AppScaffold()),
    // Add your pages here
  ];
}
