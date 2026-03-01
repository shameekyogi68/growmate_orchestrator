import 'package:flutter/material.dart';
import '../core/theme/growmate_theme.dart';
import '../core/utils/priority_color_mapper.dart';
import '../core/models/api_models.dart';

/// ConfidenceBadge — displays backend confidence_score as a color-coded pill.
/// Strict rule: only use backend value. Never calculate internally.
class ConfidenceBadge extends StatelessWidget {
  final double confidenceScore;

  const ConfidenceBadge({required this.confidenceScore, super.key});

  @override
  Widget build(BuildContext context) {
    final color = PriorityColorMapper.forConfidenceScore(confidenceScore);
    final label = PriorityColorMapper.labelForConfidenceScore(confidenceScore);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}

/// AlertCard — renders a single backend AdvisoryAlert.
/// Color is sourced from backend color_code, never hardcoded here.
class AlertCard extends StatelessWidget {
  final AdvisoryAlert alert;

  const AlertCard({required this.alert, super.key});

  @override
  Widget build(BuildContext context) {
    final borderColor = PriorityColorMapper.fromHexCode(alert.colorCode);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: GrowMateTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        boxShadow: GrowMateTheme.cardShadow,
        border: Border(
          left: BorderSide(color: borderColor, width: 4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: borderColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_mapIcon(alert.icon), size: 18, color: borderColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        alert.source.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: borderColor,
                          letterSpacing: 0.8,
                          fontFamily: 'Inter',
                        ),
                      ),
                      _PriorityBadge(level: alert.priorityLevel),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.message,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: GrowMateTheme.textPrimary,
                      fontFamily: 'Inter',
                    ),
                  ),
                  if (alert.actionText != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      alert.actionText!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: borderColor,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _mapIcon(String icon) {
    switch (icon) {
      case 'error_outline':
        return Icons.error_outline;
      case 'warning_amber':
        return Icons.warning_amber;
      case 'check_circle':
        return Icons.check_circle;
      case 'report_problem':
        return Icons.report_problem;
      default:
        return Icons.warning;
    }
  }
}

class _PriorityBadge extends StatelessWidget {
  final String level;
  const _PriorityBadge({required this.level});

  @override
  Widget build(BuildContext context) {
    final color = PriorityColorMapper.forPriorityLevel(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        level,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          fontFamily: 'Inter',
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// SkeletonCard — shimmer placeholder while advisory loads.
class SkeletonCard extends StatefulWidget {
  final double height;
  const SkeletonCard({this.height = 90, super.key});

  @override
  State<SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<SkeletonCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        height: widget.height,
        margin: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(_anim.value),
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

/// DegradedBanner — displayed when rainfall or other services return DEGRADED.
class DegradedBanner extends StatelessWidget {
  final String source;
  final String message;

  const DegradedBanner({
    required this.source,
    required this.message,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: GrowMateTheme.dangerRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: GrowMateTheme.dangerRed.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.signal_wifi_statusbar_connected_no_internet_4,
              color: GrowMateTheme.dangerRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${source.toUpperCase()} — DEGRADED',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: GrowMateTheme.dangerRed,
                    letterSpacing: 0.5,
                    fontFamily: 'Inter',
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    color: GrowMateTheme.textSecondary,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
