import 'package:dio/dio.dart';
import 'dart:io';
import 'subscription_exceptions.dart';

/// Utility class for extracting user-friendly error messages from exceptions
class ErrorHandler {
  /// Extract a user-friendly error message from any exception
  static String getErrorMessage(dynamic error) {
    // Handle subscription-related exceptions first
    if (error is QuotaExceededException) {
      return '${error.quotaDisplayName} quota exceeded. ${error.resetTimeMessage}';
    } else if (error is SubscriptionRequiredException) {
      return error.message;
    } else if (error is InvalidDiscountCodeException) {
      return error.friendlyMessage;
    } else if (error is SubscriptionActivationException) {
      return error.message;
    } else if (error is ExistingSubscriptionException) {
      return error.message;
    } else if (error is DioException) {
      return _getDioErrorMessage(error);
    } else if (error is SocketException) {
      return 'Network connection error. Please check your internet connection.';
    } else if (error is FileSystemException) {
      return 'File system error: ${error.message}';
    } else if (error is FormatException) {
      return 'Invalid data format: ${error.message}';
    } else if (error is Exception) {
      // Extract message from Exception
      final message = error.toString();
      if (message.startsWith('Exception: ')) {
        return message.substring(11); // Remove 'Exception: ' prefix
      }
      return message;
    } else {
      return error.toString();
    }
  }

  /// Extract error message from DioException
  static String _getDioErrorMessage(DioException error) {
    // Handle specific subscription-related status codes first
    final statusCode = error.response?.statusCode;
    if (statusCode == 429) {
      // Quota exceeded - extract quota info from response
      if (error.response?.data != null && error.response!.data is Map) {
        final data = error.response!.data as Map<String, dynamic>;
        final quotaType = data['quota_type'] as String?;
        final resetTime = data['reset_time'] as String?;
        if (quotaType != null) {
          final quota = QuotaExceededException(
            quotaType,
            resetTime: resetTime != null ? DateTime.tryParse(resetTime) : null,
          );
          return '${quota.quotaDisplayName} quota exceeded. ${quota.resetTimeMessage}';
        }
      }
      return 'Quota exceeded. Please upgrade your plan or wait for quota reset.';
    } else if (statusCode == 403) {
      // Subscription required - check if it's a feature access issue
      if (error.response?.data != null && error.response!.data is Map) {
        final data = error.response!.data as Map<String, dynamic>;
        final errorType = data['error_type'] as String?;
        if (errorType == 'subscription_required') {
          final feature = data['feature'] as String? ?? 'This feature';
          final requiredTier = data['required_tier'] as String? ?? 'paid';
          return '$feature requires $requiredTier tier or higher.';
        }
      }
    }
    
    // Try to extract error message from response data
    if (error.response?.data != null) {
      final data = error.response!.data;
      
      // If data is a Map, look for common error fields
      if (data is Map<String, dynamic>) {
        // Check for 'detail' field (FastAPI standard)
        if (data['detail'] != null) {
          final detail = data['detail'];
          if (detail is String) {
            return detail;
          } else if (detail is List && detail.isNotEmpty) {
            // Validation errors from FastAPI
            return detail.map((e) => e['msg'] ?? e.toString()).join('; ');
          } else if (detail is Map) {
            return detail['msg']?.toString() ?? detail.toString();
          }
        }
        
        // Check for 'message' field
        if (data['message'] != null) {
          return data['message'].toString();
        }
        
        // Check for 'error' field
        if (data['error'] != null) {
          return data['error'].toString();
        }
        
        // Check for 'errors' field
        if (data['errors'] != null) {
          final errors = data['errors'];
          if (errors is String) {
            return errors;
          } else if (errors is List && errors.isNotEmpty) {
            return errors.join('; ');
          }
        }
      } else if (data is String && data.isNotEmpty) {
        return data;
      }
    }

    // Fallback to DioException type messages
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout. Please check your internet connection and try again.';
      case DioExceptionType.sendTimeout:
        return 'Request timeout. The server is taking too long to respond.';
      case DioExceptionType.receiveTimeout:
        return 'Response timeout. The server is taking too long to respond.';
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        if (statusCode != null) {
          return _getStatusCodeMessage(statusCode);
        }
        return 'Server returned an error response.';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      case DioExceptionType.connectionError:
        return 'Cannot connect to server. Please check your internet connection.';
      case DioExceptionType.badCertificate:
        return 'SSL certificate verification failed.';
      case DioExceptionType.unknown:
        if (error.error is SocketException) {
          return 'Network connection error. Please check your internet connection.';
        }
        return 'An unexpected error occurred. Please try again.';
    }
  }

  /// Get user-friendly message for HTTP status codes
  static String _getStatusCodeMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Invalid request. Please check your input.';
      case 401:
        return 'Authentication required. Please log in.';
      case 403:
        return 'Access denied. You may need to upgrade your subscription.';
      case 404:
        return 'The requested resource was not found.';
      case 409:
        return 'A conflict occurred. The resource may already exist.';
      case 422:
        return 'Validation error. Please check your input.';
      case 429:
        return 'Quota exceeded. Please upgrade your plan or wait for quota reset.';
      case 500:
        return 'Server error. Please try again later.';
      case 502:
        return 'Bad gateway. The server is temporarily unavailable.';
      case 503:
        return 'Service unavailable. Please try again later.';
      case 504:
        return 'Gateway timeout. The server is taking too long to respond.';
      default:
        if (statusCode >= 500) {
          return 'Server error ($statusCode). Please try again later.';
        } else if (statusCode >= 400) {
          return 'Request error ($statusCode). Please check your input.';
        }
        return 'An error occurred ($statusCode).';
    }
  }
}

