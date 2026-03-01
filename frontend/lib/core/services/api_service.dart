import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/api_models.dart';

/// ApiService — all HTTP calls to GrowMate Orchestrator backend.
/// Strictly follows BACKEND_INTEGRATION_CONTRACT.md field names and paths.
class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  String? _token;

  Future<String?> get _authToken async {
    _token ??= await _loadToken();
    return _token;
  }

  Future<void> saveAuthData(AuthResponse auth) async {
    _token = auth.token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', auth.token);
    await prefs.setString('user_id', auth.userId);
    await prefs.setString('language', auth.profile.language);
    if (auth.profile.activeCrop != null) await prefs.setString('active_crop', auth.profile.activeCrop!);
    else await prefs.remove('active_crop');
    if (auth.profile.activeSowingDate != null) await prefs.setString('active_sowing_date', auth.profile.activeSowingDate!);
    else await prefs.remove('active_sowing_date');
    if (auth.profile.latitude != null) await prefs.setDouble('latitude', auth.profile.latitude!);
    else await prefs.remove('latitude');
    if (auth.profile.longitude != null) await prefs.setDouble('longitude', auth.profile.longitude!);
    else await prefs.remove('longitude');
  }

  Future<String?> _loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> clearAuthData() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_id');
    await prefs.remove('language');
    await prefs.remove('active_crop');
    await prefs.remove('active_sowing_date');
    await prefs.remove('latitude');
    await prefs.remove('longitude');
  }

  // ─── Private Helpers ──────────────────────────────────────────────────────

  Map<String, String> _headers({bool requiresAuth = false, String? token}) {
    final h = <String, String>{'Content-Type': 'application/json'};
    final t = token ?? _token;
    if (requiresAuth && t != null) {
      h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  Uri _uri(String path, [Map<String, String>? queryParams]) {
    final base = Uri.parse(ApiConfig.baseUrl);
    return base.replace(path: path, queryParameters: queryParams);
  }

  Future<Map<String, dynamic>> _handleResponse(http.Response res) async {
    final body = jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body as Map<String, dynamic>;
    }
    final detail = (body is Map) ? (body['detail'] ?? res.reasonPhrase) : res.reasonPhrase;
    throw ApiException(statusCode: res.statusCode, detail: detail.toString());
  }

  // ─── Auth Endpoints ───────────────────────────────────────────────────────

  Future<AuthResponse> register({
    required String phoneNumber,
    String? fullName,
    String language = 'en',
    double? latitude,
    double? longitude,
    String? activeCrop,
    String? activeSowingDate,
    String? quickPin,
  }) async {
    final res = await http
        .post(
          _uri(ApiConfig.register),
          headers: _headers(),
          body: jsonEncode({
            'phone_number': phoneNumber,
            if (fullName != null) 'full_name': fullName,
            'language': language,
            if (latitude != null) 'latitude': latitude,
            if (longitude != null) 'longitude': longitude,
            if (activeCrop != null) 'active_crop': activeCrop,
            if (activeSowingDate != null) 'active_sowing_date': activeSowingDate,
            if (quickPin != null) 'quick_pin': quickPin,
          }),
        )
        .timeout(ApiConfig.receiveTimeout);
    final data = await _handleResponse(res);
    final auth = AuthResponse.fromJson(data);
    await saveAuthData(auth);
    return auth;
  }

  Future<AuthResponse> login({
    required String phoneNumber,
    required String pin,
  }) async {
    return quickLogin(phoneNumber: phoneNumber, pin: pin);
  }

  Future<AuthResponse> quickLogin({
    required String phoneNumber,
    required String pin,
  }) async {
    final res = await http
        .post(
          _uri(ApiConfig.quickLogin),
          headers: _headers(),
          body: jsonEncode({'phone_number': phoneNumber, 'pin': pin}),
        )
        .timeout(ApiConfig.receiveTimeout);
    final data = await _handleResponse(res);
    final auth = AuthResponse.fromJson(data);
    await saveAuthData(auth);
    return auth;
  }

  // ─── Profile Endpoints ────────────────────────────────────────────────────

  Future<UserProfile> getProfile() async {
    final token = await _authToken;
    final res = await http
        .get(_uri(ApiConfig.profile), headers: _headers(requiresAuth: true, token: token))
        .timeout(ApiConfig.receiveTimeout);
    final data = await _handleResponse(res);
    return UserProfile.fromJson(data);
  }

  Future<void> updateProfile({
    String? fullName,
    String? language,
    double? latitude,
    double? longitude,
  }) async {
    final token = await _authToken;
    final body = <String, dynamic>{};
    if (fullName != null) body['full_name'] = fullName;
    if (language != null) body['language'] = language;
    if (latitude != null) body['latitude'] = latitude;
    if (longitude != null) body['longitude'] = longitude;

    final res = await http
        .patch(
          _uri(ApiConfig.profile),
          headers: _headers(requiresAuth: true, token: token),
          body: jsonEncode(body),
        )
        .timeout(ApiConfig.receiveTimeout);
    await _handleResponse(res);
  }

  // ─── Crop Endpoints ───────────────────────────────────────────────────────

  Future<List<UserCrop>> getCrops() async {
    final token = await _authToken;
    final res = await http
        .get(_uri(ApiConfig.crops), headers: _headers(requiresAuth: true, token: token))
        .timeout(ApiConfig.receiveTimeout);
    final raw = await http
        .get(_uri(ApiConfig.crops), headers: _headers(requiresAuth: true, token: token))
        .timeout(ApiConfig.receiveTimeout);
    if (raw.statusCode >= 200 && raw.statusCode < 300) {
      final list = jsonDecode(raw.body) as List<dynamic>;
      return list
          .map((e) => UserCrop.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    final body = jsonDecode(raw.body);
    throw ApiException(
        statusCode: raw.statusCode,
        detail: (body['detail'] ?? 'Failed to fetch crops').toString());
  }

  Future<int> addCrop({
    required String cropName,
    String? variety,
    required String sowingDate,
    double? latitude,
    double? longitude,
    bool isPrimary = false,
  }) async {
    final token = await _authToken;
    final res = await http
        .post(
          _uri(ApiConfig.crops),
          headers: _headers(requiresAuth: true, token: token),
          body: jsonEncode({
            'crop_name': cropName,
            if (variety != null) 'variety': variety,
            'sowing_date': sowingDate,
            if (latitude != null) 'latitude': latitude,
            if (longitude != null) 'longitude': longitude,
            'is_primary': isPrimary,
          }),
        )
        .timeout(ApiConfig.receiveTimeout);
    final data = await _handleResponse(res);
    return data['crop_id'] as int? ?? 0;
  }

  Future<void> setPrimaryCrop(int cropId) async {
    final token = await _authToken;
    final res = await http
        .patch(
          _uri(ApiConfig.cropSetPrimary(cropId)),
          headers: _headers(requiresAuth: true, token: token),
        )
        .timeout(ApiConfig.receiveTimeout);
    await _handleResponse(res);
  }

  Future<void> deleteCrop(int cropId) async {
    final token = await _authToken;
    final res = await http
        .delete(
          _uri(ApiConfig.cropDelete(cropId)),
          headers: _headers(requiresAuth: true, token: token),
        )
        .timeout(ApiConfig.receiveTimeout);
    await _handleResponse(res);
  }

  // ─── Advisory Endpoints ───────────────────────────────────────────────────

  Future<AdvisoryResponse> getFarmerAdvisory({
    required String userId,
    required double latitude,
    required double longitude,
    required String date,
    String? crop,
    String? variety,
    String language = 'en',
    String? sowingDate,
  }) async {
    final token = await _authToken;
    final res = await http
        .post(
          _uri(ApiConfig.farmerAdvisory),
          headers: _headers(requiresAuth: true, token: token),
          body: jsonEncode({
            'user_id': userId,
            'latitude': latitude,
            'longitude': longitude,
            'date': date,
            if (crop != null) 'crop': crop,
            if (variety != null) 'variety': variety,
            'language': language,
            if (sowingDate != null) 'sowing_date': sowingDate,
            'intelligence_only': false,
          }),
        )
        .timeout(ApiConfig.receiveTimeout);
    final data = await _handleResponse(res);
    return AdvisoryResponse.fromJson(data);
  }

  Future<Map<String, dynamic>> getSupportedCrops({
    double latitude = 13.8,
    double longitude = 74.6,
    String? date,
    String language = 'en',
  }) async {
    final params = <String, String>{
      'latitude': latitude.toString(),
      'longitude': longitude.toString(),
      'language': language,
      if (date != null) 'date': date,
    };
    final res = await http
        .get(_uri(ApiConfig.supportedCrops, params))
        .timeout(ApiConfig.receiveTimeout);
    return await _handleResponse(res);
  }

  Future<Map<String, dynamic>> getHealth() async {
    final res = await http
        .get(_uri(ApiConfig.health))
        .timeout(ApiConfig.connectTimeout);
    return await _handleResponse(res);
  }
}

/// Thrown when the backend returns a non-2xx status.
class ApiException implements Exception {
  final int statusCode;
  final String detail;

  const ApiException({required this.statusCode, required this.detail});

  bool get isUnauthorized => statusCode == 401;
  bool get isRateLimited => statusCode == ApiConfig.rateLimitStatusCode;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
  bool get isServerError => statusCode >= 500;

  @override
  String toString() => 'ApiException($statusCode): $detail';
}
