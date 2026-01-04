import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide MultipartFile;
import '../providers/settings_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_constants.dart';

/// Base API client with automatic authentication header injection
/// All API services should extend this class or use an instance of it
class ApiClient {
  final SettingsProvider? _settingsProvider;
  final AuthProvider? _authProvider;
  late final Dio _dio;

  ApiClient({
    SettingsProvider? settingsProvider,
    AuthProvider? authProvider,
    Dio? dio,
  })  : _settingsProvider = settingsProvider,
        _authProvider = authProvider {
    _dio = dio ?? Dio();
    _setupDio();
  }

  /// Get the underlying Dio instance for direct access if needed
  Dio get dio => _dio;

  /// Get current mock mode setting
  bool get useMockMode => _settingsProvider?.useMockMode ?? false;

  /// Get API base URL
  String get baseUrl =>
      _settingsProvider?.apiBaseUrl ?? ApiConfig.defaultBaseUrl;

  /// Get full API URL with version
  String get apiUrl => '$baseUrl/api/v1';

  /// Setup Dio with interceptors and default configuration
  void _setupDio() {
    _dio.options.baseUrl = apiUrl;
    _dio.options.headers['Content-Type'] = 'application/json';
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.options.receiveTimeout = const Duration(minutes: 5);

    // Add authentication interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Add authentication headers if user is authenticated
        if (_authProvider?.isAuthenticated == true) {
          try {
            final session = Supabase.instance.client.auth.currentSession;
            if (session?.accessToken != null) {
              options.headers['authorization'] = 'Bearer ${session!.accessToken}';
            }
          } catch (e) {
            print('Error getting auth token: $e');
          }
        }

        // Always add user ID header if available
        final userId = _authProvider?.userId ?? '';
        if (userId.isNotEmpty) {
          options.headers['X-User-ID'] = userId;
        }

        return handler.next(options);
      },
      onError: (error, handler) async {
        // Handle 401 Unauthorized errors by refreshing token and retrying
        if (error.response?.statusCode == 401 && 
            _authProvider?.isAuthenticated == true) {
          print('🔄 Received 401, attempting to refresh token...');
          
          try {
            // Attempt to refresh the session
            final response = await Supabase.instance.client.auth.refreshSession();
            final newSession = response.session;
            
            if (newSession?.accessToken != null) {
              print('✅ Token refreshed successfully, retrying request...');
              
              // Update the failed request with new token
              error.requestOptions.headers['authorization'] = 
                  'Bearer ${newSession!.accessToken}';
              
              // Retry the request with new token
              try {
                final retryResponse = await _dio.fetch(error.requestOptions);
                return handler.resolve(retryResponse);
              } catch (e) {
                print('❌ Retry failed after token refresh: $e');
                return handler.next(error);
              }
            } else {
              print('❌ Token refresh returned null session');
              return handler.next(error);
            }
          } catch (e) {
            print('❌ Token refresh failed: $e');
            return handler.next(error);
          }
        }
        
        return handler.next(error);
      },
    ));

    // Add logging interceptor for development
    if (!useMockMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: false, // Set to true for debugging
        requestHeader: true,
        responseHeader: false,
        error: true,
      ));
    }
  }

  /// Make a GET request
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    return _dio.get<T>(
      path,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// Make a POST request
  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    return _dio.post<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// Make a PUT request
  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    return _dio.put<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// Make a DELETE request
  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    return _dio.delete<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
    );
  }

  /// Make a PATCH request
  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    return _dio.patch<T>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
      onReceiveProgress: onReceiveProgress,
    );
  }

  /// Upload a file using multipart/form-data
  Future<Response<T>> uploadFile<T>(
    String path, {
    required String fileFieldName,
    required String filePath,
    String? fileName,
    Map<String, dynamic>? additionalData,
    ProgressCallback? onSendProgress,
  }) async {
    final formData = FormData.fromMap({
      fileFieldName: await MultipartFile.fromFile(
        filePath,
        filename: fileName,
      ),
      if (additionalData != null) ...additionalData,
    });

    return post<T>(
      path,
      data: formData,
      onSendProgress: onSendProgress,
    );
  }

  /// Upload file from bytes
  Future<Response<T>> uploadFileFromBytes<T>(
    String path, {
    required String fileFieldName,
    required List<int> bytes,
    required String fileName,
    Map<String, dynamic>? additionalData,
    ProgressCallback? onSendProgress,
  }) async {
    final formData = FormData.fromMap({
      fileFieldName: MultipartFile.fromBytes(
        bytes,
        filename: fileName,
      ),
      if (additionalData != null) ...additionalData,
    });

    return post<T>(
      path,
      data: formData,
      onSendProgress: onSendProgress,
    );
  }

  /// Close the client and clean up resources
  void dispose() {
    _dio.close();
  }
}

