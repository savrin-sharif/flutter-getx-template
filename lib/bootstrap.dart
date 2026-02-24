import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_storage/get_storage.dart';

import 'core/services/api_service.dart';
import 'material_app.dart';

Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize connectivity listener
  ConnectivityService();

  // Initialize dotenv
  await dotenv.load(fileName: "assets/envs/.env");

  // Initialize GetStorage
  await GetStorage.init();

  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const TemplateApp());
}
