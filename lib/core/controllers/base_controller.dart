import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';

import '../../shared/widgets/snack_bar/app_snack_bar.dart';

class RunResult<T> {
  final T? data;
  final String? errorMessage;

  const RunResult.success(this.data) : errorMessage = null;
  const RunResult.error(this.errorMessage) : data = null;

  bool get isSuccess => errorMessage == null;
}

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

  /// Returns a RunResultT containing either the data or an error message.
  /// Allows the caller to handle backend and Dio errors without triggering snack bars.
  Future<RunResult<T>> runWithLoadingResult<T>({
    required String key,
    required Future<T> Function() task,
    String defaultErrorMessage = 'Something went wrong. Please try again.',
  }) async {
    setLoadingState(key, true);
    try {
      final data = await task();
      return RunResult.success(data);
    } on DioException catch (e) {
      final msg = _extractDioErrorMessage(e) ?? defaultErrorMessage;
      return RunResult.error(msg);
    } catch (_) {
      return RunResult.error(defaultErrorMessage);
    } finally {
      setLoadingState(key, false);
    }
  }

  String? _extractDioErrorMessage(DioException e) {
    // Prefer backend JSON message
    final data = e.response?.data;

    if (data is Map) {
      // Common formats:
      // {message: "..."} / {detail: "..."} / {error: "..."}
      final message = data['message']?.toString();
      if (message != null && message.isNotEmpty) return message;

      final detail = data['detail']?.toString();
      if (detail != null && detail.isNotEmpty) return detail;

      final error = data['error']?.toString();
      if (error != null && error.isNotEmpty) return error;

      // Some APIs return {errors: ["..."]} or {errors: {...}}
      final errors = data['errors'];
      if (errors is List && errors.isNotEmpty) {
        return errors.first.toString();
      }
    }

    // If response is plain text
    if (data is String && data.trim().isNotEmpty) {
      return data;
    }

    // Fallback: Dio message (usually generic)
    final msg = e.message?.toString();
    if (msg != null && msg.isNotEmpty) return msg;

    return null;
  }
}
