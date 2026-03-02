/// GrowMate Backend API Configuration.
/// All values strictly derived from backend contract.
/// Do NOT change endpoint paths without updating backend.
class ApiConfig {
  ApiConfig._();

  // ─── Base URL ─────────────────────────────────────────────────────────────
  // Update this to your live Render URL before going to production.
  static const String baseUrl = 'https://growmate-orchestrator.onrender.com';

  // ─── Timeouts ──────────────────────────────────────────────────────────────
  // Backend orchestration timeout is 12s. We give 15s client-side buffer.
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // ─── Auth ──────────────────────────────────────────────────────────────────
  static const String tokenExpiredDetail = 'Token has expired';
  static const String tokenInvalidDetail = 'Invalid token';
  static const String tokenMissingDetail = 'Invalid or missing token';

  // ─── User Endpoints ────────────────────────────────────────────────────────
  static const String register   = '/user/register';
  static const String login      = '/user/login';
  static const String quickLogin = '/user/quick-login';
  static const String profile    = '/user/profile';
  static const String crops      = '/user/crops';
  static String cropSetPrimary(int cropId) => '/user/crops/$cropId/set-primary';
  static String cropDelete(int cropId)     => '/user/crops/$cropId';

  // ─── Advisory Endpoints ───────────────────────────────────────────────────
  static const String farmerAdvisory = '/farmer-advisory';
  static const String supportedCrops = '/supported-crops';
  static const String health          = '/health';

  // ─── Rate Limit Status Codes ──────────────────────────────────────────────
  static const int rateLimitStatusCode = 429;
}
