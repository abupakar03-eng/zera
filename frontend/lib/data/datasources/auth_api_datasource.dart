import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/constants/api_constants.dart';

class AuthApiDatasource {
  final Dio _dio;

  AuthApiDatasource(this._dio);

  /// Safely extract error message from a DioException response.
  /// Handles cases where response.data is HTML/String (e.g. nginx rate-limit page).
  String _extractError(DioException e, String fallback) {
    final data = e.response?.data;
    final status = e.response?.statusCode;

    if (status == 429) return 'Too many attempts. Please wait a minute and try again.';

    if (data is Map) {
      final detail = data['detail'];
      if (detail is List) {
        final msgs = (detail as List)
            .map((d) => (d is Map) ? d['msg']?.toString() ?? '' : d.toString())
            .where((m) => m.isNotEmpty)
            .join(', ');
        return msgs.isNotEmpty ? msgs : fallback;
      }
      if (detail != null) return detail.toString();
    }

    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.unknown) {
      return 'Cannot connect to server. Check your internet connection.';
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Connection timed out. Please try again.';
    }

    return fallback;
  }

  Future<Map<String, dynamic>> register({
    required String phone,
    required String password,
    required String fullName,
    String? email,
    required String businessName,
    required String businessPhone,
    String? businessEmail,
    String? referralCode,
  }) async {
    try {
      final body = {
        'phone': phone,
        'password': password,
        'full_name': fullName,
        'email': email,
        'business_name': businessName,
        'business_phone': businessPhone,
        'business_email': businessEmail,
        if (referralCode != null && referralCode.isNotEmpty)
          'referral_code': referralCode.trim().toUpperCase(),
      };
      final response = await _dio.post(
        '${ApiConstants.baseUrl}${ApiConstants.authRegister}',
        data: body,
      );
      if (response.statusCode == 201 &&
          response.data is Map &&
          response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      } else {
        final detail = (response.data is Map) ? response.data['detail'] : null;
        throw Exception(detail?.toString() ?? 'Registration failed');
      }
    } on DioException catch (e) {
      throw Exception(_extractError(e, 'Registration failed'));
    }
  }

  Future<Map<String, dynamic>> login({
    required String phone,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}${ApiConstants.authLogin}',
        data: {
          'phone': phone,
          'password': password,
        },
      );
      if (response.statusCode == 200 &&
          response.data is Map &&
          response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      } else {
        final detail = (response.data is Map) ? response.data['detail'] : null;
        throw Exception(detail?.toString() ?? 'Login failed');
      }
    } on DioException catch (e) {
      debugPrint('Login DioException: ${e.type} | ${e.message}');
      throw Exception(_extractError(e, 'Login failed'));
    }
  }

  Future<void> sendOtp({
    required String phone,
    required String purpose,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}${ApiConstants.authOtpSend}',
        data: {
          'phone': phone,
          'purpose': purpose,
        },
      );
      if (response.statusCode != 200 ||
          !(response.data is Map) ||
          response.data['success'] != true) {
        final detail = (response.data is Map) ? response.data['detail'] : null;
        throw Exception(detail?.toString() ?? 'Failed to send OTP');
      }
    } on DioException catch (e) {
      throw Exception(_extractError(e, 'Failed to send OTP'));
    }
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otpCode,
    required String purpose,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}${ApiConstants.authOtpVerify}',
        data: {
          'phone': phone,
          'otp_code': otpCode,
          'purpose': purpose,
        },
      );
      if (response.statusCode == 200 &&
          response.data is Map &&
          response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      } else {
        final detail = (response.data is Map) ? response.data['detail'] : null;
        throw Exception(detail?.toString() ?? 'OTP verification failed');
      }
    } on DioException catch (e) {
      throw Exception(_extractError(e, 'OTP verification failed'));
    }
  }

  Future<Map<String, dynamic>> getCurrentUser(String token) async {
    try {
      final response = await _dio.get(
        '${ApiConstants.baseUrl}${ApiConstants.authMe}',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );
      if (response.statusCode == 200 &&
          response.data is Map &&
          response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      } else {
        final detail = (response.data is Map) ? response.data['detail'] : null;
        throw Exception(detail?.toString() ?? 'Failed to get user data');
      }
    } on DioException catch (e) {
      throw Exception(_extractError(e, 'Failed to get user data'));
    }
  }

  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}${ApiConstants.authRefresh}',
        data: {
          'refresh_token': refreshToken,
        },
      );
      if (response.statusCode == 200 &&
          response.data is Map &&
          response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      } else {
        final detail = (response.data is Map) ? response.data['detail'] : null;
        throw Exception(detail?.toString() ?? 'Token refresh failed');
      }
    } on DioException catch (e) {
      throw Exception(_extractError(e, 'Token refresh failed'));
    }
  }

  Future<Map<String, dynamic>> googleAuth(String supabaseToken) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/auth/google',
        data: {'supabase_token': supabaseToken},
      );
      if (response.statusCode == 200 &&
          response.data is Map &&
          response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      }
      final detail = (response.data is Map) ? response.data['detail'] : null;
      throw Exception(detail?.toString() ?? 'Google auth failed');
    } on DioException catch (e) {
      throw Exception(_extractError(e, 'Google auth failed'));
    }
  }

  Future<Map<String, dynamic>> googleCompleteRegistration({
    required String supabaseToken,
    required String phone,
    required String businessName,
    String? businessPhone,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/auth/google/complete',
        data: {
          'supabase_token': supabaseToken,
          'phone': phone,
          'business_name': businessName,
          'business_phone': businessPhone ?? phone,
        },
      );
      if (response.statusCode == 201 &&
          response.data is Map &&
          response.data['success'] == true) {
        return response.data['data'] as Map<String, dynamic>;
      }
      final detail = (response.data is Map) ? response.data['detail'] : null;
      throw Exception(detail?.toString() ?? 'Registration failed');
    } on DioException catch (e) {
      throw Exception(_extractError(e, 'Registration failed'));
    }
  }

  Future<void> resetPassword({
    required String phone,
    required String newPassword,
    required String otpCode,
  }) async {
    try {
      final response = await _dio.post(
        '${ApiConstants.baseUrl}/auth/reset-password',
        data: {
          'phone': phone,
          'new_password': newPassword,
          'otp_code': otpCode,
        },
      );
      if (response.statusCode != 200 ||
          !(response.data is Map) ||
          response.data['success'] != true) {
        final detail = (response.data is Map) ? response.data['detail'] : null;
        throw Exception(detail?.toString() ?? 'Password reset failed');
      }
    } on DioException catch (e) {
      throw Exception(_extractError(e, 'Password reset failed'));
    }
  }
}
