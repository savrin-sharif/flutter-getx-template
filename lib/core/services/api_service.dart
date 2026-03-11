import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart' show Get, GetNavigation;
import 'package:get_storage/get_storage.dart';

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
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();

  // ── ANSI ─────────────────────────────────────────────────────────────────
  static const _r   = '\x1B[0m';
  static const _b   = '\x1B[1m';
  static const _dim = '\x1B[2m';

  static const _green  = '\x1B[32m';
  static const _cyan   = '\x1B[36m';
  static const _white  = '\x1B[37m';

  static const _bRed    = '\x1B[91m';
  static const _bGreen  = '\x1B[92m';
  static const _bYellow = '\x1B[93m';
  static const _bBlue   = '\x1B[94m';

  // JSON syntax colours
  static const _jKey   = '\x1B[31m';        // light red     → keys
  static const _jStr   = '\x1B[94m';        // bright blue   → string values
  static const _jNum   = '\x1B[92m';        // bright green  → numbers
  static const _jBool  = '\x1B[93m';        // bright yellow → true / false
  static const _jNull  = '\x1B[1m\x1B[37m'; // bold white    → null
  static const _jPunctuation = '\x1B[37m';        // white         → { } [ ] , :

  // ── Box-drawing ───────────────────────────────────────────────────────────
  static const _boxW  = 72;
  static const _boxTl = '┌';
  static const _boxMl = '├';
  static const _boxBl = '└';
  static const _boxVl = '│';
  static const _boxHr = '─';
  static const _boxDs = '┄';

  // ── Request buffer (keyed by full URI string) ─────────────────────────────
  final _pending = <String, _ReqBuf>{};

  // ── Diagnostic helpers ────────────────────────────────────────────────────

  void debug(String msg)   => _log(_dim,     '🐛', 'DEBUG', msg);
  void verbose(String msg) => _log(_dim,     '💬', 'TRACE', msg);
  void info(String msg)    => _log(_cyan,    '💡', 'INFO',  msg);
  void warn(String msg)    => _log(_bYellow, '⚠️ ', 'WARN',  msg);

  void error(String msg, [dynamic err, StackTrace? st]) {
    final parts = [msg];
    if (err != null) { parts.add('Error: $err'); }
    if (st  != null) { parts.add('Stack:\n$st'); }
    _log(_bRed, '❌', 'ERROR', parts.join('\n'));
  }

  // ── HTTP API ──────────────────────────────────────────────────────────────

  /// Called from onRequest interceptor. Stores the request; prints nothing yet.
  /// [key] must be the same value passed to [logResponse] — use uri.toString().
  void logRequest(
      String method,
      Uri uri, {
        Map<String, dynamic>? headers,
        dynamic payload,
        required String key,
      }) {
    _pending[key] = _ReqBuf(
      method  : method,
      uri     : uri,
      headers : headers ?? {},
      payload : payload,
      ts      : DateTime.now(),
    );
  }

  /// Called from onResponse / onError interceptor.
  /// Pops the matching request buffer and prints both in one block.
  /// [key] must equal the value used in [logRequest] — use requestOptions.uri.toString().
  void logResponse(
      int? statusCode,
      dynamic data, {
        required String key,
      }) {
    final buf = _pending.remove(key);

    final code       = statusCode ?? 0;
    final is2xx      = code >= 200 && code < 300;
    final is3xx      = code >= 300 && code < 400;
    final respColor  = is2xx ? _bGreen : (is3xx ? _bYellow : _bRed);
    final statusText = _httpStatusText(code);

    final dBar = '$_dim${_boxDs * _boxW}$_r';
    final vl   = '$_b$_white$_boxVl$_r';

    final lines = <String>[];

    // ── top + timestamp ───────────────────────────────────────────────────
    lines.add('$_b$_white$_boxTl${_boxHr * _boxW}$_r');
    lines.add('$vl  $_dim${_ts(buf?.ts ?? DateTime.now())}$_r');

    // ── REQUEST section ───────────────────────────────────────────────────
    if (buf != null) {
      lines.add('$_boxMl$dBar');
      lines.add('$vl  $_b$_bBlue━━  REQUEST$_r');
      lines.add(vl);

      final mc = _methodClr(buf.method);
      lines.add('$vl  $mc$_b[${buf.method}]$_r  $_cyan${buf.uri}$_r');
      lines.add(vl);

      // headers
      lines.add('$vl  $_b$_white📑  HEADERS$_r');
      _maskHeaders(buf.headers).forEach((k, v) {
        lines.add('$vl     $_dim$k$_r $_white$v$_r');
      });
      lines.add(vl);

      // body / payload
      lines.add('$vl  $_b$_white📦  BODY$_r');
      for (final l in _fmt(buf.payload).split('\n')) {
        lines.add('$vl     $_green$l$_r');
      }
    }

    // ── RESPONSE section ──────────────────────────────────────────────────
    lines.add('$_boxMl$dBar');
    lines.add('$vl  $respColor$_b━━  RESPONSE  $code $statusText$_r');
    lines.add(vl);

    final bodyStr = _json(data);
    const maxLen  = 4000;
    final clipped = bodyStr.length > maxLen;
    final display = clipped ? bodyStr.substring(0, maxLen) : bodyStr;

    lines.add('$vl  $_b$_white📄  BODY$_r');
    for (final l in display.split('\n')) {
      lines.add('$vl     ${_jsonLine(l)}');
    }
    if (clipped) {
      lines.add('$vl     $_dim… truncated (${bodyStr.length} chars total)$_r');
    }

    // ── bottom border ─────────────────────────────────────────────────────
    lines.add('$_b$_white$_boxBl${_boxHr * _boxW}$_r');

    // Print every line individually — avoids debugPrint's 800-char truncation
    for (final l in lines) {
      // ignore: avoid_print
      print(l);
    }
  }

  // ── Private ───────────────────────────────────────────────────────────────

  void _log(String color, String emoji, String level, String msg) {
    final vl = '$_b$_white$_boxVl$_r';
    final lines = <String>[
      '$_b$_white$_boxTl${_boxHr * _boxW}$_r',
      '$vl  $_dim${_ts(DateTime.now())}  [$level]$_r',
      '$_boxMl$_dim${_boxDs * _boxW}$_r',
      ...msg.split('\n').map((l) => '$vl  $color$emoji  $l$_r'),
      '$_b$_white$_boxBl${_boxHr * _boxW}$_r',
    ];
    for (final l in lines) {
      // ignore: avoid_print
      print(l);
    }
  }

  String _ts(DateTime dt) =>
      '${dt.year}-${_p(dt.month)}-${_p(dt.day)} '
          '${_p(dt.hour)}:${_p(dt.minute)}:${_p(dt.second)}';

  String _p(int v) => v.toString().padLeft(2, '0');

  String _methodClr(String m) {
    switch (m.toUpperCase()) {
      case 'GET':    return _bBlue;
      case 'POST':   return _bGreen;
      case 'PUT':    return _bYellow;
      case 'PATCH':  return _bYellow;
      case 'DELETE': return _bRed;
      default:       return _white;
    }
  }

  String _httpStatusText(int code) {
    const map = {
      200: 'OK', 201: 'Created', 204: 'No Content',
      400: 'Bad Request', 401: 'Unauthorized', 403: 'Forbidden',
      404: 'Not Found', 409: 'Conflict', 422: 'Unprocessable',
      429: 'Too Many Requests', 500: 'Server Error', 503: 'Unavailable',
    };
    return map[code] ?? '';
  }

  Map<String, dynamic> _maskHeaders(Map<String, dynamic> h) {
    final m = Map<String, dynamic>.from(h);
    if (m.containsKey('Authorization')) {
      final raw   = m['Authorization'].toString();
      final token = raw.replaceFirst('Bearer ', '');
      m['Authorization'] = token.length > 12
          ? 'Bearer ${token.substring(0, 6)}…${token.substring(token.length - 6)}'
          : raw;
    }
    return m;
  }

  String _fmt(dynamic payload) {
    if (payload == null) { return '<empty>'; }
    if (payload is Map || payload is List) {
      try { return const JsonEncoder.withIndent('  ').convert(payload); }
      catch (_) {}
    }
    if (payload is FormData) {
      final fields = {for (final e in payload.fields) e.key: e.value};
      final files  = payload.files.map((e) => {
        'key': e.key, 'filename': e.value.filename,
        'contentType': e.value.contentType?.toString(),
      }).toList();
      try { return const JsonEncoder.withIndent('  ').convert({'fields': fields, 'files': files}); }
      catch (_) {}
    }
    return payload.toString();
  }

  String _json(dynamic data) {
    if (data == null) { return '<empty>'; }
    if (data is Map || data is List) {
      try { return const JsonEncoder.withIndent('  ').convert(data); }
      catch (_) {}
    }
    return data.toString();
  }

  /// Syntax-highlights a single line of pretty-printed JSON:
  ///   keys          → light red
  ///   string values → bright blue
  ///   numbers       → bright green
  ///   true / false  → bright yellow
  ///   null          → bold white
  ///   punctuation   → plain white
  String _jsonLine(String line) {
    final kvM = RegExp(r'^(\s*)("(?:[^"\\]|\\.)*")(\s*:\s*)(.+?)(,?)$')
        .firstMatch(line);
    if (kvM != null) {
      return '${kvM[1]!}$_jKey${kvM[2]!}$_r'
          '$_jPunctuation${kvM[3]!}$_r'
          '${_colorValue(kvM[4]!)}'
          '$_jPunctuation${kvM[5]!}$_r';
    }

    final trimmed = line.trimLeft();
    final indent  = line.substring(0, line.length - trimmed.length);

    if (RegExp(r'^[{}\[\]],?$').hasMatch(trimmed)) {
      return '$indent$_jPunctuation$trimmed$_r';
    }

    if (trimmed.startsWith('"')) {
      final comma = trimmed.endsWith(',') ? ',' : '';
      final raw   = comma.isEmpty ? trimmed : trimmed.substring(0, trimmed.length - 1);
      return '$indent$_jStr$raw$_r$_jPunctuation$comma$_r';
    }

    return '$indent${_colorValue(trimmed)}';
  }

  /// Returns the ANSI-coloured representation of a JSON value token.
  String _colorValue(String v) {
    final core  = v.endsWith(',') ? v.substring(0, v.length - 1) : v;
    final comma = v.endsWith(',') ? ',' : '';

    if (core == 'null') {
      return '$_jNull$core$_r$_jPunctuation$comma$_r';
    }
    if (core == 'true' || core == 'false') {
      return '$_jBool$core$_r$_jPunctuation$comma$_r';
    }
    if (RegExp(r'^-?\d+(\.\d+)?$').hasMatch(core)) {
      return '$_jNum$core$_r$_jPunctuation$comma$_r';
    }
    if (core.startsWith('"')) {
      return '$_jStr$core$_r$_jPunctuation$comma$_r';
    }
    return '$_jPunctuation$v$_r';
  }
}

/// Holds a staged request until its matching response arrives.
class _ReqBuf {
  final String method;
  final Uri    uri;
  final Map<String, dynamic> headers;
  final dynamic payload;
  final DateTime ts;
  _ReqBuf({
    required this.method,
    required this.uri,
    required this.headers,
    required this.payload,
    required this.ts,
  });
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
        validateStatus: (status) {
          // Let 2xx through as success; everything else is an error
          // so onError interceptor fires for 401/403
          return status != null && status >= 200 && status < 300;
        },
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
          logger.logRequest(
            options.method,
            options.uri,
            headers: options.headers,
            payload: options.data,
            key: options.uri.toString(),
          );
          handler.next(options);
        },
        onResponse: (response, handler) {
          logger.logResponse(
            response.statusCode,
            response.data,
            key: response.requestOptions.uri.toString(),
          );
          handler.next(response);
        },
        onError: (e, handler) {
          final isConnectionError = e.type == DioExceptionType.connectionError ||
              e.message?.toLowerCase().contains('failed host lookup') == true;

          // Always flush the pending request buffer so REQUEST+RESPONSE appear together
          logger.logResponse(
            e.response?.statusCode ?? (isConnectionError ? 0 : -1),
            e.response?.data ?? (isConnectionError ? 'Connection Error' : e.message),
            key: e.requestOptions.uri.toString(),
          );

          if (isConnectionError) {
            showSnack(
              content: 'Check your internet or try again later',
              status: SnackBarStatus.disconnected,
            );
          } else {
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

          logger.logRequest(
            options.method,
            options.uri,
            headers: options.headers,
            payload: options.data,
            key: options.uri.toString(),
          );

          handler.next(options);
        },

        onResponse: (response, handler) {
          logger.logResponse(
            response.statusCode,
            response.data,
            key: response.requestOptions.uri.toString(),
          );
          handler.next(response);
        },

        onError: (e, handler) async {
          final statusCode = e.response?.statusCode;
          final responseBody = e.response?.data;
          final isUnauthorized = statusCode == 401 ||
              (statusCode == 403 && isUnauthorizedError(e.response?.data));
          final isConnectionError = e.type == DioExceptionType.connectionError ||
              e.message?.toLowerCase().contains('failed host lookup') == true;

          // Connectivity error — flush buffer with no-network indicator
          if (isConnectionError) {
            logger.logResponse(
              0,
              'Connection Error',
              key: e.requestOptions.uri.toString(),
            );
            showSnack(
              content: 'Check your internet or try again later',
              status: SnackBarStatus.disconnected,
            );
            return handler.next(e);
          }

          // Non-auth error (400, 422, 500, etc.) — flush buffer with real response body
          if (!isUnauthorized) {
            logger.logResponse(
              statusCode,
              responseBody,
              key: e.requestOptions.uri.toString(),
            );
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
