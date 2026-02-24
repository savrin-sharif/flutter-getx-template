import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_service.dart';
import 'base_api_response.dart';

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
        message: 'No internet connection',
        data: null,
        statusCode: null,
      );
    }

    try {
      logger.info('[BaseService][$operation] Starting request...');
      final response = await request();
      final data = response.data;

      debugPrint(
        'safeRequest[$operation]: statusCode=${response.statusCode}, dataType=${data.runtimeType}',
      );

      final result = BaseApiResponse<T>.fromHttp(response, fromJson);

      logger.info(
        '[BaseService][$operation] Completed with success=${result.success} (status=${result.statusCode})',
      );

      return result;
    } on AppException catch (e) {
      // Raised by ApiService.handleError(...)
      logger.error(
        '[BaseService][$operation] AppException: ${e.message} (status=${e.statusCode})',
        e,
      );
      return BaseApiResponse<T>(
        success: false,
        message: e.message,
        data: null,
        statusCode: e.statusCode,
      );
    } on DioException catch (e) {
      final isConnectionError = e.type == DioExceptionType.connectionError ||
          (e.message?.toLowerCase().contains('failed host lookup') ?? false);

      logger.error(
        '[BaseService][$operation] DioException: ${e.message}',
        e,
      );
      debugPrint('safeRequest[$operation]: isConnectionError: $isConnectionError');

      return BaseApiResponse<T>(
        success: false,
        message: isConnectionError
            ? 'Check your internet or try again later'
            : 'Something went wrong. Please try again',
        data: null,
        statusCode: e.response?.statusCode,
      );
    } catch (e, stackTrace) {
      logger.error(
        '[BaseService][$operation] Unknown error: $e',
        e,
        stackTrace,
      );

      return BaseApiResponse<T>(
        success: false,
        message: 'Something went wrong. Please try again',
        data: null,
        statusCode: null,
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
        message: 'No internet connection',
        data: null,
        statusCode: null,
      );
    }

    try {
      logger.info('[BaseService][$operation] Starting async task...');
      final result = await task();
      logger.info(
        '[BaseService][$operation] Completed with success=${result.success} (status=${result.statusCode})',
      );
      return result;
    } catch (e, stackTrace) {
      logger.error(
        '[BaseService][$operation] Unknown error in async task: $e',
        e,
        stackTrace,
      );

      return BaseApiResponse<T>(
        success: false,
        message: 'Something went wrong. Please try again',
        data: null,
        statusCode: null,
      );
    }
  }
}
