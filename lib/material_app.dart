import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/bindings/global_bindings.dart';
import 'core/routes/app_pages.dart';
import 'core/routes/app_routes.dart';
import 'core/services/api_service.dart';
import 'core/themes/app_theme.dart';
import 'shared/widgets/scaffold/app_scaffold.dart';

class TemplateApp extends StatelessWidget {
  const TemplateApp({super.key});

  String _getInitialRoute() {
    final authTokenService = AuthTokenService();
    final token = authTokenService.accessToken;

    if (token != null && token.isNotEmpty) {
      return AppRoutes.appRoot;
    }
    return AppRoutes.appRoot;
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Template App',
      theme: appTheme(context),
      initialBinding: GlobalBindings(),
      initialRoute: _getInitialRoute(),
      getPages: AppPages.pages,
      home: const AppScaffold(),
    );
  }
}
