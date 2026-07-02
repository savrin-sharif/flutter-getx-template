import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'base_api_response.dart';
import '../translations/app_strings.dart';

abstract class BaseService {
  final ApiService api = ApiService.instance;
  final AuthTokenService authTokenService = AuthTokenService();
  final ConnectivityService connectivity = ConnectivityService.instance;
  final LoggerService logger = LoggerService();

  /// For REST / Dio-based HTTP calls
  Future<BaseApiResponse<T>> safeRequest<T>({
    required String operation,
    required Future<Response> Function() request,
    required T Function(dynamic json)? fromJson,
  }) async {
    // 1) Connectivity guard at the data layer
    final hasNetwork = await connectivity.refreshStatus();
    if (!hasNetwork) {
      logger.warn('[BaseService][$operation] Blocked: no internet');
      return BaseApiResponse<T>(
        success: false,
        message: AppStrings.commonNoInternetConnection,
        data: null,
        statusCode: null,
      );
    }

    try {
      final response = await request();
      final data = response.data;

      debugPrint(
        'safeRequest[$operation]: statusCode=${response.statusCode}, dataType=${data.runtimeType}',
      );

      final result = BaseApiResponse<T>.fromHttp(response, fromJson);

      return result;
    } on AppException catch (e) {
      // Raised by ApiService.handleError(...)
      logger.error(
        '[BaseService][$operation] AppException: ${e.message} (status=${e.statusCode})',
        e,
      );
      final body = e.body;
      final errors =
          body is Map<String, dynamic> && body['errors'] is Map<String, dynamic>
          ? body['errors'] as Map<String, dynamic>
          : null;
      final message = body is Map<String, dynamic> && body['message'] != null
          ? body['message'].toString()
          : e.message;

      return BaseApiResponse<T>(
        success: false,
        message: message,
        data: null,
        statusCode: e.statusCode,
        errors: errors,
        raw: body,
      );
    } on DioException catch (e) {
      final isConnectionError =
          e.type == DioExceptionType.connectionError ||
          (e.message?.toLowerCase().contains('failed host lookup') ?? false);
      final body = e.response?.data;
      final errors =
          body is Map<String, dynamic> && body['errors'] is Map<String, dynamic>
          ? body['errors'] as Map<String, dynamic>
          : null;
      final message = body is Map<String, dynamic> && body['message'] != null
          ? body['message'].toString()
          : isConnectionError
          ? AppStrings.commonCheckYourInternetOrTryAgainLater
          : AppStrings.commonSomethingWentWrongPleaseTryAgain;

      // Interceptor already logged this — no duplicate error block needed
      return BaseApiResponse<T>(
        success: false,
        message: message,
        data: null,
        statusCode: e.response?.statusCode,
        errors: errors,
        raw: body,
      );
    } catch (e, stackTrace) {
      logger.error(
        '[BaseService][$operation] Unknown error: $e',
        e,
        stackTrace,
      );

      return BaseApiResponse<T>(
        success: false,
        message: AppStrings.commonSomethingWentWrongPleaseTryAgain,
        data: null,
        statusCode: null,
        raw: e,
      );
    }
  }

  /// For Firestore / Firebase / any async operation that already returns BaseApiResponse
  Future<BaseApiResponse<T>> safeAsync<T>({
    required String operation,
    required Future<BaseApiResponse<T>> Function() task,
  }) async {
    // 1) Connectivity guard
    final hasNetwork = await connectivity.refreshStatus();
    if (!hasNetwork) {
      logger.warn('[BaseService][$operation] Blocked: no internet');
      return BaseApiResponse<T>(
        success: false,
        message: AppStrings.commonNoInternetConnection,
        data: null,
        statusCode: null,
      );
    }

    try {
      final result = await task();
      return result;
    } catch (e, stackTrace) {
      logger.error(
        '[BaseService][$operation] Unknown error in async task: $e',
        e,
        stackTrace,
      );

      return BaseApiResponse<T>(
        success: false,
        message: AppStrings.commonSomethingWentWrongPleaseTryAgain,
        data: null,
        statusCode: null,
      );
    }
  }
}
