import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../error/app_failure.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  final config = ref.watch(appConfigProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      sendTimeout: const Duration(seconds: 12),
      responseType: ResponseType.json,
      contentType: Headers.jsonContentType,
      headers: const {'Accept': 'application/json'},
    ),
  );

  dio.interceptors.add(AppApiInterceptor(config: config));

  return ApiClient(dio: dio);
});

class ApiClient {
  ApiClient({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const _tenantIdExtraKey = 'tenantId';

  Future<Map<String, dynamic>> get(
    String path, {
    required String tenantId,
    Map<String, String>? queryParameters,
    int expectedStatusCode = 200,
  }) async {
    final response = await _request(
      () => _dio.get<dynamic>(
        path,
        queryParameters: queryParameters,
        options: Options(extra: {_tenantIdExtraKey: tenantId}),
      ),
    );

    _requireStatus(response, expectedStatusCode);
    return _decodeObject(response.data);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    required String tenantId,
    required Map<String, dynamic> body,
    int expectedStatusCode = 200,
  }) async {
    final response = await _request(
      () => _dio.post<dynamic>(
        path,
        data: body,
        options: Options(extra: {_tenantIdExtraKey: tenantId}),
      ),
    );

    _requireStatus(response, expectedStatusCode);
    return _decodeObject(response.data);
  }

  void _requireStatus(Response<dynamic> response, int expectedStatusCode) {
    if (response.statusCode != expectedStatusCode) {
      throw AppFailure.unknown(
        'Unexpected response status: '
        '${response.statusCode ?? 'unknown'}. '
        'Expected $expectedStatusCode.',
      );
    }
  }

  Future<Response<dynamic>> _request(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      final failure = error.error;
      if (failure is AppFailure) {
        throw failure;
      }

      throw _mapDioException(error);
    } on TimeoutException {
      throw AppFailure.timeout();
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw AppFailure.unknown();
    }
  }

  AppFailure _mapDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return AppFailure.timeout();

      case DioExceptionType.connectionError:
        return AppFailure.offline();

      case DioExceptionType.badResponse:
        return _mapBadResponse(error.response);

      case DioExceptionType.cancel:
        return AppFailure.unknown('Request was cancelled.');

      case DioExceptionType.badCertificate:
        return AppFailure.unknown('Bad SSL certificate.');

      case DioExceptionType.unknown:
        return AppFailure.unknown();
      default:
        return AppFailure.unknown();
    }
  }

  AppFailure _mapBadResponse(Response<dynamic>? response) {
    final statusCode = response?.statusCode;

    if (statusCode == 400) {
      final data = response?.data;
      final message = data is Map<String, dynamic>
          ? data['message']?.toString()
          : null;

      return AppFailure.validation(message ?? 'Invalid request.');
    }

    if (statusCode == 401) {
      return AppFailure.sessionExpired();
    }

    if (statusCode == 403) {
      return AppFailure.forbiddenTenant();
    }

    if (statusCode == 429) {
      final retryAfterRaw = response?.headers.value('retry-after');
      final seconds = int.tryParse(retryAfterRaw ?? '') ?? 30;
      return AppFailure.rateLimited(Duration(seconds: seconds));
    }

    if (statusCode == 502) {
      return AppFailure.providerFailure();
    }

    return AppFailure.unknown(
      'Request failed with status ${statusCode ?? 'unknown'}.',
    );
  }

  Map<String, dynamic> _decodeObject(dynamic data) {
    if (data == null) {
      return <String, dynamic>{};
    }

    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), value));
    }

    throw AppFailure.unknown('Unexpected response format.');
  }
}

class AppApiInterceptor extends Interceptor {
  AppApiInterceptor({required this.config});

  final AppConfig config;

  static const _tenantIdExtraKey = 'tenantId';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final tenantId = options.extra[_tenantIdExtraKey]?.toString();

    if (tenantId == null || tenantId.trim().isEmpty) {
      return handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.unknown,
          error: AppFailure.forbiddenTenant(),
          message: 'Missing tenant id.',
        ),
      );
    }

    options.headers['Authorization'] = 'Bearer ${config.accessToken}';
    options.headers['X-Tenant-Id'] = tenantId;
    options.headers['Content-Type'] = Headers.jsonContentType;
    options.headers['Accept'] = 'application/json';

    return handler.next(options);
  }
}
