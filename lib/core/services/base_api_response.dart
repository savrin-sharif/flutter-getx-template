import 'package:dio/dio.dart';

class BaseApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final int? statusCode;

  BaseApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.statusCode,
  });

  factory BaseApiResponse.fromHttp(
      Response response,
      T Function(dynamic json)? fromData,
      ) {
    final code = response.statusCode;
    final body = response.data;

    // If server returns envelope: { success, message, data }
    if (body is Map<String, dynamic> && (body.containsKey('success') || body.containsKey('data'))) {
      return BaseApiResponse<T>(
        success: (body['success'] as bool?) ??
            ((code ?? 0) >= 200 && (code ?? 0) < 400),
        message: body['message']?.toString() ?? 'Success',
        data: fromData != null ? fromData(body['data'] ?? body) : null,
        statusCode: code,
      );
    }

    // Raw array/object responses
    return BaseApiResponse<T>(
      success: (code ?? 0) >= 200 && (code ?? 0) < 400,
      message: ((code ?? 0) >= 200 && (code ?? 0) < 400) ? 'Success' : 'Error',
      data: fromData != null ? fromData(body) : null,
      statusCode: code,
    );
  }

  factory BaseApiResponse.fromJson(
      Map<String, dynamic> json,
      T Function(dynamic json)? fromData,
      ) {
    return BaseApiResponse<T>(
      success: json['success'] ?? true,
      message: json['message'] ?? 'Success',
      data: fromData != null ? fromData(json['data'] ?? json) : null,
      statusCode: json['statusCode'] is int ? json['statusCode'] as int : null,
    );
  }
}
