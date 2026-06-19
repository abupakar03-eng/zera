import 'package:flutter/foundation.dart';

class ApiConstants {
  // Override with --dart-define=API_BASE_URL=... at build time
  // Web default: LAN IP so phones on same WiFi can also access the store
  // Mobile default: LAN IP directly
  static String get baseUrl {
    const envUrl = String.fromEnvironment('API_BASE_URL');
    if (envUrl.isNotEmpty) return envUrl;
    // Always use LAN IP — works for dev machine browser AND phones on same WiFi
    return 'http://127.0.0.1:8000/v1';
  }

  // Web app base URL (Flutter web) — used for sharing store links
  static String get webAppUrl {
    const envUrl = String.fromEnvironment('WEB_APP_URL');
    if (envUrl.isNotEmpty) return envUrl;
    return 'http://localhost:8081';
  }

  /// Returns the public store URL for customers
  static String storeUrl(String businessUuid, {String? storeSlug}) =>
      '$webAppUrl/store/${storeSlug ?? businessUuid}';

  static String get serverUrl => baseUrl.replaceAll('/v1', '');

  static String get uploadUrl => '$serverUrl/uploads';

  static String fullUrl(String path) {
    if (path.startsWith('http')) return path;
    // Backend returns paths like /uploads/logos/uuid.jpg — just prepend server host
    if (path.startsWith('/')) return '$serverUrl$path';
    // Relative path without leading slash — assume under /uploads/
    return '$uploadUrl/$path';
  }

  static const String authRegister = '/auth/register';
  static const String authLogin = '/auth/login';
  static const String authOtpSend = '/auth/otp/send';
  static const String authOtpVerify = '/auth/otp/verify';
  static const String authRefresh = '/auth/refresh';
  static const String authMe = '/auth/me';

  static const String businessProfile = '/business/profile';
  static const String businessLogo = '/business/logo';
  static const String businessImages = '/business/images';
  static const String businessBanner = '/business/banner';
  static const String businessStats = '/business/stats';

  static const String dashboardStats = '/dashboard/stats';

  static const String categories = '/categories';
  static const String products = '/products';
  static String productImages(String uuid) => '/products/$uuid/images';
  static const String customers = '/customers';
  static const String orders = '/orders';
  static const String reports = '/reports';
  static const String admin = '/admin';
}
