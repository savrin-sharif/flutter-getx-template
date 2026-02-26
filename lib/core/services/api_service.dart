import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart' show Get, GetNavigation;
import 'package:get_storage/get_storage.dart';
import 'package:logger/logger.dart';

import '../../shared/widgets/snack_bar/app_snack_bar.dart';
import '../routes/app_routes.dart';

/// ===========================================================================
///                            ERROR UTILITIES
/// ===========================================================================
class AppException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic body;

  AppException(this.message, {this.statusCode, this.body});

  @override
  String toString() => message;
}

/// ===========================================================================
///                            LOGGER SERVICE
/// ===========================================================================
class LoggerService {
  // Singleton instance
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  // Create logger with PrettyPrinter config
  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 0,
      lineLength: 40,
      colors: true,
      levelColors: PrettyPrinter.defaultLevelColors,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.dateAndTime,
    ),
  );

  /// Log debug level message
  void debug(String message) {
    _logger.d(message);
  }

  /// Log verbose level message
  void verbose(String message) {
    _logger.t(message);
  }

  /// Log info level message
  void info(String message) {
    _logger.i(message);
  }

  /// Log warning level message
  void warn(String message) {
    _logger.w(message);
  }

  /// Log error level message with optional error object and stack trace
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Log HTTP request method and URI
  void logRequest(String method, Uri uri) {
    _logger.i('📡 [REQUEST] $method => $uri');
  }

  /// Log HTTP headers map
  void logHeaders(Map<String, dynamic> headers) {
    final maskedHeaders = Map<String, dynamic>.from(headers);

    if (maskedHeaders.containsKey('Authorization')) {
      final auth = maskedHeaders['Authorization'].toString();
      final token = auth.replaceFirst('Bearer ', '');
      final masked = token.length > 12
          ? 'Bearer ${token.substring(0, 6)}...${token.substring(token.length - 6)}'
          : auth;

      maskedHeaders['Authorization'] = masked;
    }

    _logger.i('📑 [HEADERS] => $maskedHeaders');
  }

  /// Log HTTP payload (request body or form data)
  void logPayload(dynamic payload) {
    if (payload == null) {
      _logger.i('📦 [PAYLOAD] => <empty>');
      return;
    }

    // Pretty-print JSON-like maps/lists
    if (payload is Map || payload is List) {
      try {
        _logger.i('📦 [PAYLOAD] => ${const JsonEncoder.withIndent('  ').convert(payload)}');
      } catch (_) {
        _logger.i('📦 [PAYLOAD] => $payload');
      }
      return;
    }

    // Expand Dio FormData (fields + files)
    if (payload is FormData) {
      final fields = <String, String>{for (final e in payload.fields) e.key: e.value};

      // Don't dump raw bytes; summarize each file safely
      final files = payload.files.map((e) {
        final f = e.value;
        return {
          'key': e.key,
          'filename': f.filename,
          'contentType': f.contentType?.toString(),
          // length may be null or expensive; include if available
          'length': (() {
            try {
              return f.length;
            } catch (_) {
              return null;
            }
          })(),
        };
      }).toList();

      final summarized = {
        'fields': fields,
        'files': files,
      };

      _logger.i('📦 [PAYLOAD] => ${const JsonEncoder.withIndent('  ').convert(summarized)}');
      return;
    }

    // Fallback
    _logger.i('📦 [PAYLOAD] => $payload');
  }

  /// Log HTTP response status code and data
  void logResponse(int? statusCode, dynamic data) {
    if (statusCode != null && statusCode >= 200 && statusCode < 300) {
      _logger.i('✅ [RESPONSE $statusCode] => $data');
    } else if (statusCode != null && statusCode < 400) {
      _logger.w('⚠️ [RESPONSE $statusCode] => $data');
    } else {
      _logger.e('❌ [RESPONSE $statusCode] => $data');
    }
  }
}

/// ===========================================================================
///                   CONNECTIVITY STREAM SERVICE (Global Subscriber)
/// ===========================================================================
class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._internal();
  factory ConnectivityService() => instance;

  final Connectivity connectivity = Connectivity();
  final ValueNotifier<bool> isOnline = ValueNotifier(true);

  ConnectivityService._internal() {
    init();
  }

  bool get isConnected => isOnline.value;

  void init() {
    // Initial check
    connectivity.checkConnectivity().then((resultList) {
      updateStatus(resultList);
    });

    // Listen to connection changes
    connectivity.onConnectivityChanged.listen((resultList) {
      updateStatus(resultList);
    });
  }

  void updateStatus(List<ConnectivityResult> results) {
    final connected = results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.wifi);

    if (connected != isOnline.value) {
      isOnline.value = connected;

      showSnack(
        content: connected ? "Back Online" : "No Internet Connection",
        status: connected
            ? SnackBarStatus.connected
            : SnackBarStatus.disconnected,
      );
    }
  }

  Future<bool> refreshStatus() async {
    final results = await connectivity.checkConnectivity();
    updateStatus(results);
    return isOnline.value;
  }

  void dispose() {
    isOnline.dispose();
  }
}

/// ===========================================================================
///                AUTH TOKEN SERVICE using GetStorage
/// ===========================================================================
class AuthTokenService {
  final GetStorage storage = GetStorage();

  static const String sessionTokenKey = 'session_token';
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';

  String? get sessionToken => storage.read<String>(sessionTokenKey);
  String? get accessToken => storage.read<String>(accessTokenKey);
  String? get refreshToken => storage.read<String>(refreshTokenKey);

  void setSessionToken(String token) => storage.write(sessionTokenKey, token);
  void setAccessToken(String token) => storage.write(accessTokenKey, token);
  void setRefreshToken(String token) => storage.write(refreshTokenKey, token);

  void setTokens({
    required String sessionToken,
    required String accessToken,
    required String refreshToken,
  }) {
    setSessionToken(sessionToken);
    setAccessToken(accessToken);
    setRefreshToken(refreshToken);
  }

  void clearTokens() {
    storage.remove(sessionTokenKey);
    storage.remove(accessTokenKey);
    storage.remove(refreshTokenKey);
  }

  void logOut() {
    LoggerService().info('[AuthTokenService] Logging out...');
    clearTokens();
    Get.offAllNamed(AppRoutes.appRoot);
    LoggerService().info('[AuthTokenService] Logged out.');
  }
}

/// ===========================================================================
///                            API SERVICE
/// ===========================================================================
enum ApiType { public, private }
enum AuthMode { backendJwt, firebaseIdToken }

class ApiAuthConfig {
  static AuthMode mode = AuthMode.backendJwt; // <-- change according to need

  // Only for backendJwt mode:
  static const String refreshPath = '/api/v1/refresh-token/'; // <-- change to real endpoint
  static const String refreshTokenField = 'refresh';
}

class ApiService {
  static final ApiService instance = ApiService.internal();

  factory ApiService() => instance;

  late final Dio publicClient;
  late final Dio privateClient;
  final AuthTokenService authStorage = AuthTokenService();
  final LoggerService logger = LoggerService();

  String resolveBaseUrl() {
    final dev = dotenv.env['DEV_URL'] ?? '';
    final prod = dotenv.env['BASE_URL'] ?? '';

    // Release build => prod, otherwise dev
    return kReleaseMode ? prod : dev;
  }

  ApiService.internal() {
    publicClient = createDioClient();
    privateClient = createDioClient();
    setupPublicInterceptors();
    setupPrivateInterceptors();
  }

  Dio createDioClient() {
    return Dio(
      BaseOptions(
        baseUrl: resolveBaseUrl(),
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        validateStatus: (status) => status != null && status < 400,
      ),
    );
  }

  Dio getClient(ApiType apiType, [String? overrideBaseUrl]) {
    final base = apiType == ApiType.public ? publicClient : privateClient;
    if (overrideBaseUrl != null && overrideBaseUrl.isNotEmpty) {
      final newClient = Dio(base.options.copyWith(baseUrl: overrideBaseUrl));
      newClient.interceptors.addAll(base.interceptors);
      return newClient;
    }
    return base;
  }

  /// =========================================================================
  ///                     PUBLIC CLIENT INTERCEPTORS
  /// =========================================================================
  void setupPublicInterceptors() {
    publicClient.interceptors.addAll([
      InterceptorsWrapper(
        onRequest: (options, handler) {
          logger.logRequest(options.method, options.uri);
          logger.logHeaders(options.headers);
          logger.logPayload(options.data);
          handler.next(options);
        },
        onResponse: (response, handler) {
          logger.logResponse(response.statusCode, response.data);
          handler.next(response);
        },
        onError: (e, handler) {
          if (e.type == DioExceptionType.connectionError ||
              e.message?.toLowerCase().contains('failed host lookup') == true) {
            logger.error('[PUBLIC API ERROR] Connection Error');
            showSnack(
              content: 'Check your internet or try again later',
              status: SnackBarStatus.disconnected,
            );
          } else {
            logger.error('[PUBLIC API ERROR] ${e.message}');
            showSnack(
              content: 'Something went wrong. Please try again.',
              status: SnackBarStatus.error,
            );
          }
          handler.next(e);
        },
      ),
    ]);
  }

  /// =========================================================================
  ///                     PRIVATE CLIENT INTERCEPTORS
  /// =========================================================================
  void setupPrivateInterceptors() {
    Completer<void>? refreshCompleter;

    privateClient.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (options.extra['skipAuth'] == true) {
            return handler.next(options);
          }

          final token = authStorage.accessToken;

          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }

          logger.logRequest(options.method, options.uri);
          logger.logHeaders(options.headers);
          logger.logPayload(options.data);

          handler.next(options);
        },

        onResponse: (response, handler) {
          logger.logResponse(response.statusCode, response.data);
          handler.next(response);
        },

        onError: (e, handler) async {
          final statusCode = e.response?.statusCode;
          final isUnauthorized = statusCode == 401 ||
              (statusCode == 403 && isUnauthorizedError(e.response?.data));

          // Connectivity error
          if (e.type == DioExceptionType.connectionError ||
              e.message?.toLowerCase().contains('failed host lookup') == true) {
            logger.error('[PRIVATE API ERROR] Connection Error: ${e.message}');
            showSnack(
              content: 'Check your internet or try again later',
              status: SnackBarStatus.disconnected,
            );
            return handler.next(e);
          }

          if (!isUnauthorized) {
            logger.error('[PRIVATE API ERROR] ${e.message}');
            return handler.next(e);
          }

          final req = e.requestOptions;
          final alreadyRetried = (req.extra['__retried__'] == true);

          if (alreadyRetried) {
            logger.error('[PRIVATE API] Unauthorized even after retry → logging out.');
            AuthTokenService().logOut();
            return handler.next(e);
          }

          logger.warn('[PRIVATE API] Unauthorized → attempting token refresh...');

          try {
            if (refreshCompleter != null) {
              await refreshCompleter!.future;
            } else {
              refreshCompleter = Completer<void>();
              await _refreshToken();
              refreshCompleter!.complete();
              refreshCompleter = null;
            }

            // Retry original request once
            req.extra['__retried__'] = true;

            final newToken = authStorage.accessToken;
            if (newToken != null && newToken.isNotEmpty) {
              req.headers['Authorization'] = 'Bearer $newToken';
            }

            final res = await privateClient.fetch(req);
            return handler.resolve(res);

          } catch (err, st) {
            logger.error('[PRIVATE API] Refresh failed → logging out.', err, st);
            AuthTokenService().logOut();
            return handler.next(e);
          }
        },
      ),
    );
  }

  Future<void> _refreshToken() async {
    final refresh = authStorage.refreshToken;

    if (refresh == null || refresh.isEmpty) {
      logger.error('[PRIVATE API] Missing refresh token → cannot refresh');
      throw AppException('Missing refresh token');
    }

    logger.warn('[PRIVATE API] Refresh call starting...');
    logger.warn('[PRIVATE API] Refresh full URL: ${privateClient.options.baseUrl}${ApiAuthConfig.refreshPath}');
    logger.warn('[PRIVATE API] Refresh field: ${ApiAuthConfig.refreshTokenField}');
    logger.warn('[PRIVATE API] Refresh token exists: ${refresh.isNotEmpty}');

    final resp = await privateClient.post(
      ApiAuthConfig.refreshPath,
      data: {
        ApiAuthConfig.refreshTokenField: refresh,
      },
      options: Options(
        extra: {'skipAuth': true}, // prevent interceptor recursion
      ),
    );

    logger.warn('[PRIVATE API] Refresh response status: ${resp.statusCode}');
    logger.warn('[PRIVATE API] Refresh response body: ${resp.data}');

    final status = resp.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      throw AppException(
        'Refresh token failed',
        statusCode: status,
        body: resp.data,
      );
    }

    final data = resp.data;
    if (data is! Map) {
      throw AppException('Invalid refresh response format');
    }

    final newAccess =
        (data['access_token'] ?? data['access'])?.toString() ?? '';
    final newRefresh =
        (data['refresh_token'] ?? data['refresh'])?.toString() ?? '';

    if (newAccess.isEmpty) {
      throw AppException('Refresh succeeded but access token missing');
    }

    authStorage.setTokens(
      sessionToken: authStorage.sessionToken ?? '',
      accessToken: newAccess,
      refreshToken: newRefresh.isNotEmpty ? newRefresh : refresh,
    );

    logger.warn('[PRIVATE API] Refresh success → tokens updated.');
  }

  static bool isUnauthorizedError(dynamic data) {
    if (data is! Map) return false;

    final code = data['code']?.toString();
    final detail = data['detail']?.toString().toLowerCase() ?? '';

    if (code == 'token_not_valid') return true;
    if (detail.contains('token')) return true;

    final messages = data['messages'];
    if (messages is List) {
      for (final m in messages) {
        final msg = (m is Map ? m['message'] : null)?.toString().toLowerCase() ?? '';
        if (msg.contains('expired') || msg.contains('not valid') || msg.contains('token')) {
          return true;
        }
      }
    }

    return false;
  }

  void handleError(Response response) {
    final status = response.statusCode ?? 0;
    if (status >= 400) {
      final data = response.data;
      String message = 'Unexpected error';

      if (data is Map<String, dynamic>) {
        message = data['message']?.toString()
            ?? data['error']?.toString()
            ?? (data['errors'] is Map
                ? (data['errors'] as Map).values.first?.first?.toString() ?? 'Invalid data'
                : 'Something went wrong');
      } else if (data != null) {
        message = data.toString();
      }

      throw AppException(message, statusCode: status, body: data);
    }
  }

  /// =========================================================================
  ///                              HTTP METHODS
  /// =========================================================================
  Future<Response> get(
      String path, {
        Map<String, dynamic>? query,
        ApiType apiType = ApiType.private,
        String? overrideBaseUrl,
        Map<String, dynamic>? headers,
      }) async {
    final client = getClient(apiType, overrideBaseUrl);
    final options = Options(
      headers: headers != null
          ? {...client.options.headers, ...headers}
          : client.options.headers,
    );

    final response = await client.get(
      path,
      queryParameters: query,
      options: options,
    );
    handleError(response);
    return response;
  }

  Future<Response> post(
      String path, {
        dynamic data,
        Map<String, dynamic>? query,
        ApiType apiType = ApiType.private,
        String? overrideBaseUrl,
        Map<String, dynamic>? headers,
      }) async {
    final client = getClient(apiType, overrideBaseUrl);
    final options = Options(
      headers: headers != null
          ? {...client.options.headers, ...headers}
          : client.options.headers,
    );

    final response = await client.post(
      path,
      data: data,
      queryParameters: query,
      options: options,
    );
    handleError(response);
    return response;
  }

  Future<Response> patch(
      String path, {
        dynamic data,
        Map<String, dynamic>? query,
        ApiType apiType = ApiType.private,
        String? overrideBaseUrl,
        Map<String, dynamic>? headers,
      }) async {
    final client = getClient(apiType, overrideBaseUrl);
    final options = Options(
      headers: headers != null
          ? {...client.options.headers, ...headers}
          : client.options.headers,
    );

    final response = await client.patch(
      path,
      data: data,
      queryParameters: query,
      options: options,
    );
    handleError(response);
    return response;
  }

  Future<Response> put(
      String path, {
        dynamic data,
        Map<String, dynamic>? query,
        ApiType apiType = ApiType.private,
        String? overrideBaseUrl,
        Map<String, dynamic>? headers,
      }) async {
    final client = getClient(apiType, overrideBaseUrl);
    final options = Options(
      headers: headers != null
          ? {...client.options.headers, ...headers}
          : client.options.headers,
    );

    final response = await client.put(
      path,
      data: data,
      queryParameters: query,
      options: options,
    );
    handleError(response);
    return response;
  }

  Future<Response> delete(
      String path, {
        dynamic data,
        Map<String, dynamic>? query,
        ApiType apiType = ApiType.private,
        String? overrideBaseUrl,
        Map<String, dynamic>? headers,
      }) async {
    final client = getClient(apiType, overrideBaseUrl);
    final options = Options(
      headers: headers != null
          ? {...client.options.headers, ...headers}
          : client.options.headers,
    );

    final response = await client.delete(
      path,
      data: data,
      queryParameters: query,
      options: options,
    );
    handleError(response);
    return response;
  }
}
