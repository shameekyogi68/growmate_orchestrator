import 'package:flutter/material.dart';
import '../../../core/models/api_models.dart';
import '../../../shared/widgets.dart';

/// Renders the list of alerts from backend. Hidden when empty.
class AlertList extends StatelessWidget {
  final List<AdvisoryAlert> alerts;

  const AlertList({required this.alerts, super.key});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Active Alerts · ಸಕ್ರಿಯ ಎಚ್ಚರಿಕೆಗಳು',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 10),
        ...alerts.map((a) => AlertCard(alert: a)),
      ],
    );
  }
}
