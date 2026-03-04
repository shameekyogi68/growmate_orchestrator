import 'package:flutter/material.dart';
import '../../../core/theme/growmate_theme.dart';
import '../../../core/utils/priority_color_mapper.dart';

/// MarketCard — renders market_prices from backend. Hidden if empty.
class MarketCard extends StatelessWidget {
  final Map<String, dynamic> marketPrices;

  const MarketCard({required this.marketPrices, super.key});

  @override
  Widget build(BuildContext context) {
    if (marketPrices.isEmpty) return const SizedBox.shrink();

    final priceList = marketPrices['price_list'] as List<dynamic>? ?? [];
    final summary = marketPrices['summary'] as String?;

    if (priceList.isEmpty && summary == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: GrowMateTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: GrowMateTheme.cardShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: GrowMateTheme.sunYellow.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.storefront_outlined,
                  color: GrowMateTheme.sunYellow, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Market Prices · ಮಾರುಕಟ್ಟೆ ಬೆಲೆಗಳು',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: GrowMateTheme.textPrimary)),
          ]),
          if (summary != null) ...[
            const SizedBox(height: 10),
            Text(summary,
                style: const TextStyle(
                    fontSize: 13, color: GrowMateTheme.textSecondary, height: 1.4)),
          ],
          if (priceList.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...priceList.take(4).map((item) {
              final name = item['crop'] ?? item['name'] ?? '';
              final price = item['price']?.toString() ?? '';
              final unit = item['unit'] ?? '';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontSize: 13, color: GrowMateTheme.textPrimary)),
                    Text('₹$price/$unit',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: GrowMateTheme.primaryGreen)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

/// PestCard — renders pest advisory from backend with priority badge.
class PestCard extends StatelessWidget {
  final Map<String, dynamic> pest;

  const PestCard({required this.pest, super.key});

  @override
  Widget build(BuildContext context) {
    if (pest.isEmpty) return const SizedBox.shrink();

    final priorityLevel = pest['priority_level'] as String?;
    final message = pest['message'] as String?;
    final alerts = pest['alerts'] as List<dynamic>? ?? [];
    final recommendations =
        pest['recommendations'] as List<dynamic>? ?? [];

    if (message == null && alerts.isEmpty) return const SizedBox.shrink();

    final color = PriorityColorMapper.forPriorityLevel(priorityLevel);

    return Container(
      decoration: BoxDecoration(
        color: GrowMateTheme.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: GrowMateTheme.cardShadow,
        border: Border(left: BorderSide(color: color, width: 3)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.bug_report_outlined, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Pest & Disease · ಕೀಟ ಮತ್ತು ರೋಗ',
                style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: GrowMateTheme.textPrimary)),
            const Spacer(),
            if (priorityLevel != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(priorityLevel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: color,
                        fontFamily: 'Inter')),
              ),
          ]),
          if (message != null) ...[
            const SizedBox(height: 10),
            Text(message,
                style: const TextStyle(
                    fontSize: 13,
                    color: GrowMateTheme.textSecondary,
                    height: 1.4)),
          ],
          if (alerts.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...alerts.take(3).map((a) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.circle, color: color, size: 6),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(a.toString(),
                            style: const TextStyle(
                                fontSize: 12,
                                color: GrowMateTheme.textSecondary)),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
