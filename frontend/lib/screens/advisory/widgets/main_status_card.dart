import 'package:flutter/material.dart';
import '../../../core/theme/growmate_theme.dart';
import '../../../core/models/api_models.dart';
import '../../../core/utils/priority_color_mapper.dart';

/// MainStatusCard — sourced entirely from backend main_status object.
/// Color comes from backend color_code. Never hardcoded here.
class MainStatusCard extends StatelessWidget {
  final MainStatus mainStatus;

  const MainStatusCard({required this.mainStatus, super.key});

  @override
  Widget build(BuildContext context) {
    final cardColor = PriorityColorMapper.fromHexCode(mainStatus.colorCode);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cardColor, cardColor.withOpacity(0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: cardColor.withOpacity(0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(_resolveIcon(mainStatus.icon),
                color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    mainStatus.statusLabel,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  mainStatus.message,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _resolveIcon(String icon) {
    switch (icon) {
      case 'report_problem':
        return Icons.report_problem_rounded;
      case 'warning':
        return Icons.warning_rounded;
      case 'error_outline':
        return Icons.error_outline_rounded;
      default:
        return Icons.check_circle_rounded;
    }
  }
}
