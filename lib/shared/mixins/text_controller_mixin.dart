import 'package:flutter/material.dart';
import 'package:get/get.dart';

mixin TextControllerMixin on GetxController {
  final Map<String, TextEditingController> textControllers = {};

  TextEditingController getTextCtrl(String key) {
    if (!textControllers.containsKey(key)) {
      textControllers[key] = TextEditingController();
    }
    return textControllers[key]!;
  }

  void disposeTextCtrl(String key) {
    if (textControllers.containsKey(key)) {
      textControllers[key]!.dispose();
      textControllers.remove(key);
    }
  }

  @override
  void onClose() {
    textControllers.forEach((_, ctrl) => ctrl.dispose());
    textControllers.clear();
    super.onClose();
  }
}
