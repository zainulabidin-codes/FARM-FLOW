import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/ledger_entry_model.dart';

enum ConflictResolutionAction {
  cancel,
  saveAsSeparate,
  mergeAndHarmonize,
  replaceExisting,
}

Future<ConflictResolutionAction?> showDuplicateShiftConflictDialog({
  required BuildContext context,
  required LedgerEntryModel existingEntry,
  required String newQuantity,
  required String session,
}) {
  final qtyKg = (existingEntry.quantityGrams! / 1000).toStringAsFixed(1);
  return showDialog<ConflictResolutionAction>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Duplicate Shift Entry'),
      content: Text(
        'A milk entry of $qtyKg Kg already exists for the $session shift today.\n\nHow would you like to handle this new entry of $newQuantity Kg?',
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(ConflictResolutionAction.mergeAndHarmonize),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepGreen,
                foregroundColor: Colors.white,
              ),
              child: const Text('Merge & Harmonize Rate'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(ConflictResolutionAction.replaceExisting),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textDark,
              ),
              child: const Text('Replace Existing'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop(ConflictResolutionAction.saveAsSeparate),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textDark,
              ),
              child: const Text('Save as Separate Load'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(ConflictResolutionAction.cancel),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textGrey,
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ],
    ),
  );
}
