import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/growmate_theme.dart';
import '../../core/services/api_service.dart';
import '../../core/models/api_models.dart';
import '../../core/localization/app_locale.dart';

class CropCalendarScreen extends StatefulWidget {
  const CropCalendarScreen({super.key});

  @override
  State<CropCalendarScreen> createState() => _CropCalendarScreenState();
}

class _CropCalendarScreenState extends State<CropCalendarScreen> {
  CropCalendarResponse? _calendar;
  bool _loading = true;
  String? _error;
  String? _activeCrop;

  @override
  void initState() {
    super.initState();
    _loadCalendar();
  }

  Future<void> _loadCalendar() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final crop = prefs.getString('active_crop');
      final sowingDate = prefs.getString('active_sowing_date');
      final lang = L.currentLang;

      if (crop == null || sowingDate == null) {
        setState(() {
          _activeCrop = null;
          _loading = false;
        });
        return;
      }

      setState(() => _activeCrop = crop);

      final result = await ApiService.instance.getCropCalendar(
        crop: crop,
        sowingDate: sowingDate,
        language: lang,
      );

      setState(() {
        _calendar = result;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = L.tr(
          'Could not load calendar. Please check your connection.',
          'ಕ್ಯಾಲೆಂಡರ್ ಲೋಡ್ ಮಾಡಲು ಸಾಧ್ಯವಾಗಲಿಲ್ಲ. ದಯವಿಟ್ಟು ಸಂಪರ್ಕ ಪರಿಶೀಲಿಸಿ.',
        );
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [_buildAppBar()],
        body: _loading
            ? _buildLoadingState()
            : _activeCrop == null
            ? _buildEmptyState()
            : _error != null
            ? _buildErrorState()
            : _buildCalendarTimeline(),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: GrowMateTheme.primaryGreenDark,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: GrowMateTheme.headerGradient,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    L.tr('Crop Timeline', 'ಬೆಳೆ ವೇಳಾಪಟ್ಟಿ'),
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _activeCrop != null
                        ? L.tr(
                            '120-Day lifecycle for $_activeCrop',
                            '$_activeCrop ಬೆಳೆಗೆ 120 ದಿನಗಳ ಚಕ್ರ',
                          )
                        : L.tr(
                            'Select a crop to see timeline',
                            'ವೇಳಾಪಟ್ಟಿ ನೋಡಲು ಬೆಳೆಯನ್ನು ಆರಿಸಿ',
                          ),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(color: GrowMateTheme.primaryGreen),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 64,
              color: GrowMateTheme.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 20),
            Text(
              L.tr('No Active Crop', 'ಯಾವುದೇ ಸಕ್ರಿಯ ಬೆಳೆ ಇಲ್ಲ'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              L.tr(
                'Add a crop in the "My Farm" tab to see its 120-day growth calendar.',
                '"ನನ್ನ ಫಾರ್ಮ್" ಟ್ಯಾಬ್‌ನಲ್ಲಿ ಬೆಳೆಯನ್ನು ಸೇರಿಸಿ ಅದರ 120 ದಿನಗಳ ಬೆಳವಣಿಗೆಯ ವೇಳಾಪಟ್ಟಿಯನ್ನು ನೋಡಿ.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(color: GrowMateTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_error ?? 'Unknown error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadCalendar,
            child: Text(L.tr('Retry', 'ಮತ್ತೆ ಪ್ರಯತ್ನಿಸಿ')),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarTimeline() {
    final months = _calendar?.timeline ?? [];
    return RefreshIndicator(
      onRefresh: _loadCalendar,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
        itemCount: months.length,
        itemBuilder: (context, mIndex) {
          final month = months[mIndex];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMonthHeader(month.month),
              const SizedBox(height: 12),
              ...month.weeks.map((week) => _buildWeekRow(week)).toList(),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMonthHeader(String monthName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: GrowMateTheme.primaryGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        monthName.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: GrowMateTheme.primaryGreenDark,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildWeekRow(CalendarWeek week) {
    final isCurrent = week.weekNumber == _calendar?.progress.currentWeek;
    final stageColor = _getStageColor(week.stage);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline logic
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? GrowMateTheme.primaryGreen
                      : Colors.grey.shade300,
                  shape: BoxShape.circle,
                  border: isCurrent
                      ? Border.all(color: Colors.white, width: 2)
                      : null,
                  boxShadow: isCurrent
                      ? [
                          BoxShadow(
                            color: GrowMateTheme.primaryGreen.withValues(
                              alpha: 0.4,
                            ),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              ),
              Expanded(child: Container(width: 2, color: Colors.grey.shade200)),
            ],
          ),
          const SizedBox(width: 16),
          // Content Card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: isCurrent
                      ? Border.all(
                          color: GrowMateTheme.primaryGreen.withValues(
                            alpha: 0.5,
                          ),
                          width: 1.5,
                        )
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      // Stage indicator line
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 4,
                        child: Container(color: stageColor),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  L.tr(
                                    'Week ${week.weekNumber}',
                                    'ವಾರ ${week.weekNumber}',
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: isCurrent
                                        ? GrowMateTheme.primaryGreen
                                        : GrowMateTheme.textSecondary,
                                  ),
                                ),
                                if (isCurrent)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: GrowMateTheme.primaryGreen,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      L.tr('TODAY', 'ಇಂದು'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              week.fieldOperation,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: GrowMateTheme.textPrimary,
                                height: 1.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Quick tags
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _buildTag(
                                  week.stage,
                                  stageColor.withValues(alpha: 0.1),
                                  stageColor,
                                ),
                                if (week.irrigation != null &&
                                    week.irrigation != "None")
                                  _buildTag(
                                    week.irrigation!,
                                    Colors.blue.withValues(alpha: 0.05),
                                    Colors.blue,
                                  ),
                                if (week.fertilizer != null &&
                                    week.fertilizer != "None")
                                  _buildTag(
                                    L.tr('Fertilizer', 'ಗೊಬ್ಬರ'),
                                    Colors.orange.withValues(alpha: 0.05),
                                    Colors.orange,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }

  Color _getStageColor(String stage) {
    final s = stage.toLowerCase();
    if (s.contains('vege')) return GrowMateTheme.primaryGreen;
    if (s.contains('repro')) return GrowMateTheme.secondaryOrange;
    if (s.contains('harvest') || s.contains('grain'))
      return GrowMateTheme.sunYellow;
    return GrowMateTheme.skyBlue;
  }
}
