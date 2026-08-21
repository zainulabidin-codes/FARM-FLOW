import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/money_utils.dart';
import '../models.dart';

// ---------------------------------------------------------------------------
// DodiCard
// ---------------------------------------------------------------------------
// Displays one milk buyer's summary inside a white rounded card.
//
// Now uses the real data-layer DodiModel. Amount-due figures are fetched
// on the detail screen — the list card shows only the buyer name, rate,
// and phone to avoid N+1 DB queries on the list.
// ---------------------------------------------------------------------------

class DodiCard extends StatelessWidget {
  final DodiModel dodi;

  /// Called when the user taps the card. Passes dodi.id as a String.
  final ValueChanged<String> onTap;

  /// Called when the user long-presses the card.
  final ValueChanged<String>? onLongPress;

  const DodiCard({
    super.key,
    required this.dodi,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // Convert paise → rupee string for display using MoneyUtils: 550 paise = Rs 5.50
    final rateLabel = '${AppStrings.currency} ${MoneyUtils.formatPaiseToRupees(dodi.defaultRatePaise)}/L';

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap(dodi.id!.toString());
      },
      onLongPress: onLongPress != null ? () {
        HapticFeedback.heavyImpact();
        onLongPress!(dodi.id!.toString());
      } : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 80),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.055),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar circle
            Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(
                color: AppColors.sageTint,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  dodi.name.isNotEmpty
                      ? dodi.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    color: AppColors.deepGreen,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Flexible Name + Phone + Rate details container
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          dodi.name,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.sageTint,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          rateLabel,
                          style: const TextStyle(
                            color: AppColors.deepGreen,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (dodi.phone != null && dodi.phone!.isNotEmpty)
                        Text(
                          dodi.phone!,
                          style: const TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            AppStrings.viewDetails,
                            style: TextStyle(
                              color: AppColors.textGrey,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(Icons.chevron_right_rounded, size: 14, color: AppColors.textGrey),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
