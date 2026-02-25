import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../shared/widgets/snack_bar/app_snack_bar.dart';

mixin BaseController on GetxController {
  final RxBool isLoading = false.obs;
  final RxMap<String, bool> loadingStates = <String, bool>{}.obs;

  void setLoading(bool value) => isLoading.value = value;

  void setLoadingState(String key, bool value) {
    loadingStates[key] = value;
  }

  bool getLoadingState(String key) {
    return loadingStates[key] ?? false;
  }

  bool get isAnyLoading => loadingStates.values.any((loading) => loading);

  void showError(String message) {
    final lowerMsg = message.toLowerCase();

    final isConnectionError = lowerMsg.contains('no internet') ||
        lowerMsg.contains('connection') ||
        lowerMsg.contains('network') ||
        lowerMsg.contains('failed host lookup');

    showSnack(
      content: message,
      status: isConnectionError
          ? SnackBarStatus.disconnected
          : SnackBarStatus.error,
    );
  }

  void showSuccess(String message) {
    showSnack(
      content: message,
      status: SnackBarStatus.success,
    );
  }

  bool validateForm(GlobalKey<FormState> formKey) {
    return formKey.currentState?.validate() ?? false;
  }

  Future<T?> runWithLoading<T>({
    required String key,
    required Future<T> Function() task,
  }) async {
    setLoadingState(key, true);
    try {
      return await task();
    } catch (e) {
      showError('Something went wrong. Please try again.');
      return null;
    } finally {
      setLoadingState(key, false);
    }
  }
}
