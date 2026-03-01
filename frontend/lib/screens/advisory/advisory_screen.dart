import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/growmate_theme.dart';
import '../../core/services/api_service.dart';
import '../../core/models/api_models.dart';
import '../../shared/widgets.dart';
import 'widgets/main_status_card.dart';
import 'widgets/alert_list.dart';
import 'widgets/rainfall_card.dart';
import 'widgets/data_cards.dart';

class AdvisoryScreen extends StatefulWidget {
  const AdvisoryScreen({super.key});

  @override
  State<AdvisoryScreen> createState() => _AdvisoryScreenState();
}

class _AdvisoryScreenState extends State<AdvisoryScreen> {
  AdvisoryResponse? _advisory;
  bool _loading = true;
  String? _errorMessage;
  bool _isRateLimited = false;

  @override
  void initState() {
    super.initState();
    _loadAdvisory();
  }

  Future<void> _loadAdvisory() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
      _isRateLimited = false;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id') ?? 'local-user';
      final language = prefs.getString('language') ?? 'en';
      final crop = prefs.getString('active_crop');
      final sowingDate = prefs.getString('active_sowing_date');
      final lat = prefs.getDouble('latitude') ?? 13.8;
      final lon = prefs.getDouble('longitude') ?? 74.6;
      final now = DateTime.now();
      final dateStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final result = await ApiService.instance.getFarmerAdvisory(
        userId: userId,
        latitude: lat,
        longitude: lon,
        date: dateStr,
        crop: crop,
        language: language,
        sowingDate: sowingDate,
      );
      if (mounted) setState(() => _advisory = result);
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await ApiService.instance.clearToken();
        if (mounted) Navigator.of(context).pushReplacementNamed('/login');
        return;
      }
      if (e.isRateLimited) {
        setState(() => _isRateLimited = true);
      } else {
        setState(() => _errorMessage = e.detail);
      }
    } catch (e) {
      setState(() => _errorMessage =
          'Could not reach server. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GrowMateTheme.backgroundCream,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, innerScrolled) => [
          _AdvisoryAppBar(advisory: _advisory),
        ],
        body: _loading
            ? _buildSkeleton()
            : _isRateLimited
                ? _buildRateLimitBanner()
                : _errorMessage != null
                    ? _buildErrorState()
                    : _advisory != null
                        ? _buildAdvisoryContent()
                        : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(children: const [
        SkeletonCard(height: 100),
        SkeletonCard(height: 75),
        SkeletonCard(height: 75),
        SkeletonCard(height: 90),
        SkeletonCard(height: 90),
      ]),
    );
  }

  Widget _buildRateLimitBanner() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_bottom_rounded,
                color: GrowMateTheme.warningAmber, size: 52),
            const SizedBox(height: 16),
            const Text('Too Many Requests',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: GrowMateTheme.textPrimary)),
            const SizedBox(height: 8),
            const Text('You\'ve exceeded the request limit. Please wait a moment.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: GrowMateTheme.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAdvisory,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: GrowMateTheme.textSecondary, size: 52),
            const SizedBox(height: 16),
            const Text('Unable to Load Advisory',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: GrowMateTheme.textPrimary)),
            const SizedBox(height: 8),
            Text(_errorMessage ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: GrowMateTheme.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadAdvisory,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvisoryContent() {
    final a = _advisory!;
    return RefreshIndicator(
      onRefresh: _loadAdvisory,
      color: GrowMateTheme.primaryGreen,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Confidence badge
          Align(
            alignment: Alignment.centerRight,
            child: ConfidenceBadge(confidenceScore: a.confidenceScore),
          ),
          const SizedBox(height: 10),

          // Main status card — color from backend
          MainStatusCard(mainStatus: a.mainStatus),
          const SizedBox(height: 16),

          // Active alerts
          AlertList(alerts: a.alerts),
          if (a.alerts.isNotEmpty) const SizedBox(height: 16),

          // Rainfall card — DEGRADED-aware
          RainfallCard(rainfall: a.rainfall),
          const SizedBox(height: 12),

          // Pest card
          PestCard(pest: a.pest),
          if (a.pest.isNotEmpty) const SizedBox(height: 12),

          // Market prices
          MarketCard(marketPrices: a.marketPrices),
          if (a.marketPrices.isNotEmpty) const SizedBox(height: 12),

          // Partial data notice
          if (a.partialData)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GrowMateTheme.warningAmber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: GrowMateTheme.warningAmber.withOpacity(0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline,
                    color: GrowMateTheme.warningAmber, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Some data services are unavailable. Advisory is based on partial information.',
                    style: TextStyle(
                        fontSize: 12, color: GrowMateTheme.warningAmber),
                  ),
                ),
              ]),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _AdvisoryAppBar extends StatelessWidget {
  final AdvisoryResponse? advisory;
  const _AdvisoryAppBar({this.advisory});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      backgroundColor: GrowMateTheme.primaryGreenDark,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(gradient: GrowMateTheme.headerGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Row(children: [
                    Icon(Icons.eco_rounded, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text('GrowMate',
                        style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white)),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    advisory != null
                        ? 'Farm Advisory · ${_formattedDate(advisory!.lastUpdated)}'
                        : 'Loading advisory...',
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
        title: const Text('Advisory',
            style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
        titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 14),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.person_outline, color: Colors.white),
          onPressed: () => Navigator.of(context).pushNamed('/profile'),
        ),
      ],
    );
  }

  String _formattedDate(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      return '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
