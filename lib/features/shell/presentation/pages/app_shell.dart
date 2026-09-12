import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';
import 'package:provider/provider.dart';

import 'package:dairy_farm_app/core/constants/app_strings.dart';
import 'package:dairy_farm_app/core/theme/app_theme.dart';
import 'package:dairy_farm_app/core/utils/app_toast.dart';
import 'package:dairy_farm_app/core/utils/money_utils.dart';
import 'package:dairy_farm_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:dairy_farm_app/features/cows/presentation/providers/cow_provider.dart';
import 'package:dairy_farm_app/features/cows/presentation/pages/cows_screen.dart';
import 'package:dairy_farm_app/features/cows/presentation/widgets/cow_age_picker.dart';
import 'package:dairy_farm_app/features/cows/presentation/models/cow_ui_model.dart'
    as ui_models;
import 'package:dairy_farm_app/features/dashboard/presentation/pages/dashboard_screen.dart';
import 'package:dairy_farm_app/features/dashboard/presentation/pages/activity_log_screen.dart';
import 'package:dairy_farm_app/features/dodi_ledger/presentation/pages/dodi_ledger_screen.dart';
import 'package:dairy_farm_app/features/dodi_ledger/presentation/pages/dodi_detail_screen.dart';
import 'package:dairy_farm_app/features/dodi_ledger/presentation/providers/dodi_provider.dart';
import 'package:dairy_farm_app/features/milk_entry/presentation/providers/milk_entry_provider.dart';
import 'package:dairy_farm_app/core/routing/app_router.dart';
import 'package:dairy_farm_app/features/dashboard/presentation/providers/dashboard_refresh_coordinator.dart';

// ---------------------------------------------------------------------------
// AppShell
// ---------------------------------------------------------------------------
// The main scaffold after login. Manages:
//   • Which of the 3 persistent tabs is visible (Home / Buyers / Herd)
//   • The cows filter selection state
//   • All real data comes from providers — no hardcoded values remain.
//
// Tab 1 (Milk) is NOT a persistent tab — it always pushes a fullscreen
// modal via the [onMilkEntryTap] callback.
// ---------------------------------------------------------------------------

import 'package:dairy_farm_app/features/dashboard/presentation/providers/activity_log_provider.dart';

class AppShell extends StatefulWidget {
  /// The DB primary key of the currently logged-in farmer.
  final int userId;
  final int initialIndex;

  const AppShell({super.key, required this.userId, this.initialIndex = 0});

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> with WidgetsBindingObserver {
  void onCowCardLongPress(String cowIdStr) => _onCowCardLongPress(cowIdStr);
  late int _currentIndex;
  String _cowsFilter = AppStrings.filterAll;
  bool _isMilkEntryOpen = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WidgetsBinding.instance.addObserver(this);

    // Run season rollups in the background on startup
    Future.microtask(() {
      if (!mounted) return;
      Provider.of<CowProvider>(context, listen: false).runStartupRollups();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Provider.of<MilkEntryProvider>(
        context,
        listen: false,
      ).fetchTodaysTotalMilk();
    }
  }

  // ── Navigation handler ────────────────────────────────────────────────────

  void _onNavTap(int index) async {
    if (index == 1) {
      if (_isMilkEntryOpen) return;
      _isMilkEntryOpen = true;
      try {
        final result = await AppRouter.pushMilkEntry(context);
        if (result != null && mounted) {
          setState(() => _currentIndex = result);
        }
      } finally {
        _isMilkEntryOpen = false;
        if (mounted) {
          context.read<ActivityLogProvider>().loadActivities(widget.userId, silent: true);
        }
      }
      return;
    }
    if (index == _currentIndex) return;
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
    setState(() => _currentIndex = index);
    if (index == 0 && mounted) {
      context.read<ActivityLogProvider>().loadActivities(widget.userId, silent: true);
    }
  }

  // ── Dodi card tap → DodiDetailScreen ─────────────────────────────────────

  void _onDodiCardTap(String dodiIdStr) async {
    final dodiProvider = Provider.of<DodiProvider>(context, listen: false);
    final dodiId = int.tryParse(dodiIdStr);
    if (dodiId == null) return;

    // Search active buyers first; fallback to archived buyers in Bin
    final dodi =
        dodiProvider.dodis.where((d) => d.id == dodiId).firstOrNull ??
        dodiProvider.deletedDodis.where((d) => d.id == dodiId).firstOrNull;
    if (dodi == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DodiDetailScreen(dodi: dodi)),
    );
    if (mounted) {
      context.read<ActivityLogProvider>().loadActivities(widget.userId, silent: true);
    }
  }

  void _onDodiCardLongPress(String dodiIdStr) async {
    final dodiId = int.tryParse(dodiIdStr);
    if (dodiId == null) return;

    final dodiProvider = Provider.of<DodiProvider>(context, listen: false);
    final dodi =
        dodiProvider.dodis.where((d) => d.id == dodiId).firstOrNull ??
        dodiProvider.deletedDodis.where((d) => d.id == dodiId).firstOrNull;

    if (dodi != null && mounted) {
      showBuyerManageModal(context, dodi);
    }
  }

  // ── Cow card tap ─────────────────────────────────────────────────────────

  void _onCowCardTap(String cowIdStr) {
    AppRouter.pushPerCowMilk(context, cowIdStr: cowIdStr);
  }

  void _onCowCardLongPress(String cowIdStr) {
    final cowId = int.tryParse(cowIdStr);
    if (cowId == null) {
      debugPrint('Error: Could not parse cowId "$cowIdStr" as int');
      return;
    }

    final cowProvider = context.read<CowProvider>();
    final cow = cowProvider.cows.where((c) => c.id == cowId).firstOrNull;
    if (cow == null) return;
    final cowName = (cow.name != null && cow.name!.trim().isNotEmpty)
        ? cow.name!
        : cow.tagNumber;

    final bool isConfirmedPregnant =
        cow.status == 'PREGNANT' ||
        cow.status == 'BRED_HEIFER' ||
        (cow.status == 'DRY' &&
            cow.matingDate != null &&
            cow.matingDate!.isNotEmpty);

    final bool isPendingConfirmation = cow.status == 'PENDING_CONFIRMATION';

    if (!isConfirmedPregnant && !isPendingConfirmation) {
      showDialog(
        context: context,
        builder: (ctx) => _DeleteCowDialog(cowId: cowId, cowName: cowName),
      ).then((_) {
        if (!mounted) return;
        context.read<ActivityLogProvider>().loadActivities(widget.userId);
      });
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: AppColors.cardWhite,
        title: Row(
          children: [
            const Icon(
              Icons.pets_rounded,
              color: AppColors.deepGreen,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Manage Cow #$cowName',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isConfirmedPregnant
                  ? 'Select an action for this confirmed pregnant cow:'
                  : 'Select an action for this pending confirmation cow:',
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            if (isConfirmedPregnant) ...[
              // End Pregnancy (Mid-Term Loss)
              InkWell(
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final success = await cowProvider.endPregnancy(
                    cowId,
                    widget.userId,
                  );
                  if (mounted) {
                    if (success) {
                      AppToast.showSuccess(
                        context,
                        '⚠️ Pregnancy ended for Cow #$cowName.',
                      );
                    } else {
                      AppToast.showError(
                        context,
                        cowProvider.errorMessage ?? 'Failed to end pregnancy.',
                      );
                    }
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFB74D)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFE65100),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'End Pregnancy (Mid-Term Loss)',
                              style: TextStyle(
                                color: Color(0xFFE65100),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Logs mid-term loss / abortion and automatically reverts cow status.',
                              style: TextStyle(
                                color: AppColors.textDark,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Override Confirmation Method
              InkWell(
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showMethodSelectionDialog(
                    context,
                    cowId,
                    cowName,
                    cow.confirmationMethod ?? 'AUTO',
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF81C784)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.edit_note_rounded,
                        color: AppColors.deepGreen,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Override Confirmation Method',
                              style: TextStyle(
                                color: AppColors.deepGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Currently: ${cow.confirmationMethod ?? "AUTO"} — Change method to Vet or Self.',
                              style: const TextStyle(
                                color: AppColors.textDark,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (isPendingConfirmation) ...[
              // Confirm Pregnancy
              InkWell(
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showMethodSelectionDialog(context, cowId, cowName, 'SELF');
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF81C784)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.favorite_rounded,
                        color: AppColors.deepGreen,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Confirm Pregnancy',
                              style: TextStyle(
                                color: AppColors.deepGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Confirm pregnancy post-mating via Self or Vet confirmation.',
                              style: TextStyle(
                                color: AppColors.textDark,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Heat Repeated / Cancel Mating
              InkWell(
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final success = await cowProvider.reportHeatRepeated(
                    cowId,
                    widget.userId,
                  );
                  if (mounted) {
                    if (success) {
                      AppToast.showSuccess(
                        context,
                        '🔄 Heat repeated logged for Cow #$cowName.',
                      );
                    } else {
                      AppToast.showError(
                        context,
                        cowProvider.errorMessage ?? 'Failed to update mating.',
                      );
                    }
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFB74D)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.refresh_rounded,
                        color: Color(0xFFE65100),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Heat Repeated / Cancel Mating',
                              style: TextStyle(
                                color: Color(0xFFE65100),
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Mating failed / heat repeated. Resets status so she can be mated again.',
                              style: TextStyle(
                                color: AppColors.textDark,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            // Option: Remove / Delete Cow
            InkWell(
              onTap: () {
                Navigator.of(ctx).pop();
                showDialog(
                  context: context,
                  builder: (ctx) =>
                      _DeleteCowDialog(cowId: cowId, cowName: cowName),
                ).then((_) {
                  if (!mounted) return;
                  context.read<ActivityLogProvider>().loadActivities(
                    widget.userId,
                  );
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFCDD2)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.warningRed,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Remove / Delete Cow',
                            style: TextStyle(
                              color: AppColors.warningRed,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Soft deletes cow record from herd tracker.',
                            style: TextStyle(
                              color: AppColors.textDark,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMethodSelectionDialog(
    BuildContext context,
    int cowId,
    String cowName,
    String currentMethod,
  ) {
    String selectedMethod = (currentMethod == 'VET' || currentMethod == 'SELF')
        ? currentMethod
        : 'VET';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('Confirmation Method — Cow #$cowName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Method: $currentMethod',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textGrey,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Select confirmation method:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: selectedMethod == 'SELF'
                            ? AppColors.sageTint
                            : Colors.transparent,
                        side: BorderSide(
                          color: selectedMethod == 'SELF'
                              ? AppColors.deepGreen
                              : Colors.grey,
                        ),
                      ),
                      onPressed: () =>
                          setStateDialog(() => selectedMethod = 'SELF'),
                      child: const Text(
                        'Self Confirmed',
                        style: TextStyle(
                          color: AppColors.deepGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: selectedMethod == 'VET'
                            ? AppColors.sageTint
                            : Colors.transparent,
                        side: BorderSide(
                          color: selectedMethod == 'VET'
                              ? AppColors.deepGreen
                              : Colors.grey,
                        ),
                      ),
                      onPressed: () =>
                          setStateDialog(() => selectedMethod = 'VET'),
                      child: const Text(
                        'Vet Confirmed',
                        style: TextStyle(
                          color: AppColors.deepGreen,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.of(ctx).pop();
                final cowProvider = context.read<CowProvider>();
                final success = await cowProvider.confirmPregnancy(
                  cowId,
                  widget.userId,
                  method: selectedMethod,
                );
                if (!mounted) return;
                if (success) {
                  AppToast.showSuccess(
                    context,
                    '✅ Pregnancy confirmed ($selectedMethod) for Cow #$cowName.',
                  );
                } else {
                  AppToast.showError(
                    context,
                    cowProvider.errorMessage ?? 'Failed to confirm pregnancy.',
                  );
                }
              },
              child: const Text('Save Method'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Add Dodi modal ────────────────────────────────────────────────────────

  void _onAddBuyerTap() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddDodiSheet(userId: widget.userId),
    );
    if (mounted) {
      Provider.of<ActivityLogProvider>(
        context,
        listen: false,
      ).loadActivities(widget.userId);
    }
  }

  // ── Add Cow modal ─────────────────────────────────────────────────────────

  void openAddCowSheet() => _onAddCowTap();

  void _onAddCowTap() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddCowSheet(userId: widget.userId),
    );
    if (mounted) {
      Provider.of<ActivityLogProvider>(
        context,
        listen: false,
      ).loadActivities(widget.userId);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  String _formatActivityTime(int timeUnix) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timeUnix);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final milkProvider = Provider.of<MilkEntryProvider>(context);
    final dodiProvider = Provider.of<DodiProvider>(context);
    final cowProvider = Provider.of<CowProvider>(context);

    // Provide farmerName to greeting (Bug 1).
    final farmName =
        authProvider.currentUser?.farmerName ??
        authProvider.currentUser?.username ??
        'Farmer';

    final activityProvider = Provider.of<ActivityLogProvider>(context);

    // Take the 3 most recent activities from the global activity log
    final recentLogItems = activityProvider.activities.take(3).toList();
    final recentActivities = recentLogItems.map((log) {
      return RecentActivity(
        title: log.title,
        subtitle: log.subtitle,
        value: log.value,
        time: _formatActivityTime(log.timeUnix),
        icon: log.icon,
        timeUnix: log.timeUnix,
        metadata: log.metadata,
        isPositive: log.isPositive == 1,
      );
    }).toList();

    final Widget currentScreen = switch (_currentIndex) {
      2 => DodiLedgerScreen(
        // DodiLedgerScreen accepts the data-layer DodiModel (via re-export)
        dodis: dodiProvider.dodis,
        currentNavIndex: _currentIndex,
        onAddBuyerTap: _onAddBuyerTap,
        onDodiCardTap: _onDodiCardTap,
        onDodiCardLongPress: _onDodiCardLongPress,
        onNavTap: _onNavTap,
      ),
      3 => CowsScreen(
        cows: cowProvider.cows
            .map(
              (c) => ui_models.CowUiModel(
                id: c.id?.toString() ?? '',
                tagNumber: c.tagNumber,
                name: c.name ?? 'Cow #${c.tagNumber}',
                status: c.status.toUpperCase() == 'DRY'
                    ? ui_models.CowStatus.dry
                    : c.status.toUpperCase() == 'HEIFER'
                    ? ui_models.CowStatus.heifer
                    : (c.status.toUpperCase() == 'BRED_HEIFER' ||
                          c.status.toUpperCase() == 'BRED HEIFER')
                    ? ui_models.CowStatus.bredHeifer
                    : c.status.toUpperCase() == 'PREGNANT'
                    ? ui_models.CowStatus.pregnant
                    : c.status.toUpperCase() == 'PENDING_CONFIRMATION'
                    ? ui_models.CowStatus.pendingConfirmation
                    : ui_models.CowStatus.milking,
                hasLactated: cowProvider.hasLactated(c.id!),
                aiDate: c.matingDate,
                pregnancyMonth: cowProvider.getPregnancyMonth(c),
                daysSinceMating: cowProvider.getDaysSinceMating(c),
                peakMorningYield: c.peakMorningYield != null
                    ? '${(c.peakMorningYield! / 1000).toStringAsFixed(1)} kg'
                    : null,
                peakEveningYield: c.peakEveningYield != null
                    ? '${(c.peakEveningYield! / 1000).toStringAsFixed(1)} kg'
                    : null,
                lowestMorningYield: c.lowestMorningYield != null
                    ? '${(c.lowestMorningYield! / 1000).toStringAsFixed(1)} kg'
                    : null,
                lowestEveningYield: c.lowestEveningYield != null
                    ? '${(c.lowestEveningYield! / 1000).toStringAsFixed(1)} kg'
                    : null,
                estimatedBirthDate: c.estimatedBirthDate,
                displayAge: cowProvider.calculateAgeString(c),
              ),
            )
            .toList(),
        selectedFilter: _cowsFilter,
        currentNavIndex: _currentIndex,
        onFilterChanged: (f) => setState(() => _cowsFilter = f),
        onAddCowTap: _onAddCowTap,
        onCowCardTap: _onCowCardTap,
        onCowCardLongPress: _onCowCardLongPress,
        onNavTap: _onNavTap,
      ),
      _ => DashboardScreen(
        farmName: farmName,
        actualFarmName: authProvider.currentUser?.farmName,
        totalMilk: milkProvider.todaysTotalMilkKg.toStringAsFixed(1),
        morningMilk: milkProvider.todaysMorningMilkKg.toStringAsFixed(1),
        eveningMilk: milkProvider.todaysEveningMilkKg.toStringAsFixed(1),
        totalCows: cowProvider.totalHerdCount.toString(),
        activeCows: cowProvider.milkingCount.toString(),
        pregnantCount: cowProvider.pregnantCount.toString(),
        dryCount: cowProvider.dryCount.toString(),
        bredHeiferCount: cowProvider.bredHeiferCount.toString(),
        heiferCount: cowProvider.heiferCount.toString(),
        recentActivities: recentActivities,
        currentNavIndex: _currentIndex,
        onMilkEntryTap: () => _onNavTap(1),
        onDodiTap: () {
          _onNavTap(2);
        },
        onAddCowTap: _onAddCowTap,
        onViewAllTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const ActivityLogScreen())),
        onNavTap: _onNavTap,
        onRefresh: () =>
            DashboardRefreshCoordinator(context).refreshAll(widget.userId),
      ),
    };
    return currentScreen;
  }
}

// ---------------------------------------------------------------------------
// _AddDodiSheet — bottom modal form for creating a new Dodi
// ---------------------------------------------------------------------------
class _AddDodiSheet extends StatefulWidget {
  final int userId;
  const _AddDodiSheet({required this.userId});

  @override
  State<_AddDodiSheet> createState() => _AddDodiSheetState();
}

class _AddDodiSheetState extends State<_AddDodiSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _rateController = TextEditingController();
  final FlutterNativeContactPicker _contactPicker =
      FlutterNativeContactPicker();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _pickContact() async {
    try {
      final Contact? contact = await _contactPicker.selectContact();
      if (contact != null) {
        final phoneNumbers = contact.phoneNumbers;
        if (phoneNumbers != null && phoneNumbers.isNotEmpty) {
          final rawPhone = phoneNumbers.first;
          final cleanPhone = rawPhone.replaceAll(RegExp(r'\D'), '');
          setState(() {
            _phoneController.text = cleanPhone;
            final fullName = contact.fullName;
            if (_nameController.text.trim().isEmpty &&
                fullName != null &&
                fullName.trim().isNotEmpty) {
              _nameController.text = fullName.trim();
            }
          });
        } else {
          if (!mounted) return;
          AppToast.showError(
            context,
            'Selected contact does not have a phone number.',
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      AppToast.showError(context, 'Could not access phone contacts.');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final dodiProvider = Provider.of<DodiProvider>(context, listen: false);
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final ratePaise = MoneyUtils.rupeesToPaise(_rateController.text);

    setState(() => _saving = true);

    final success = await dodiProvider.addDodi(
      userId: widget.userId,
      name: name,
      phone: phone.isEmpty ? null : phone,
      ratePaise: ratePaise,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (success) {
      Navigator.of(context).pop();
      AppToast.showSuccess(context, '✅ $name added as a buyer.');
    } else {
      final err = Provider.of<DodiProvider>(
        context,
        listen: false,
      ).errorMessage;
      AppToast.showError(context, err ?? 'Failed to add buyer.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      margin: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Add Milk Buyer',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 20),

            // Name field
            TextFormField(
              controller: _nameController,
              decoration: AppTheme.filledInputDecoration(
                labelText: 'Buyer Name *',
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Name is required' : null,
            ),
            const SizedBox(height: 14),

            // Phone field (manual entry + contact picker option)
            TextFormField(
              controller: _phoneController,
              decoration: AppTheme.filledInputDecoration(
                labelText: 'Phone Number (Optional)',
                prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(
                    Icons.contacts_rounded,
                    color: AppColors.deepGreen,
                    size: 22,
                  ),
                  onPressed: _pickContact,
                  tooltip: 'Select from phone contacts',
                ),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null; // Optional
                final digitsOnly = v.replaceAll(RegExp(r'\D'), '');
                if (digitsOnly.length < 7 || digitsOnly.length > 15) {
                  return 'Enter a valid phone number (7-15 digits)';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Rate field
            TextFormField(
              controller: _rateController,
              decoration: AppTheme.filledInputDecoration(
                labelText: 'Default Rate (${AppStrings.currency}/litre) *',
                prefixIcon: const Icon(Icons.payments_outlined, size: 20),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Rate is required';
                }
                final parsed = double.tryParse(v.trim());
                if (parsed == null || parsed <= 0) {
                  return 'Enter a valid rate (e.g. 5.50)';
                }
                return null;
              },
            ),
            const SizedBox(height: 28),

            // Save button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Buyer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AddCowSheet — bottom modal form for adding a new cow
// ---------------------------------------------------------------------------
class _AddCowSheet extends StatefulWidget {
  final int userId;
  const _AddCowSheet({required this.userId});

  @override
  State<_AddCowSheet> createState() => _AddCowSheetState();
}

class _AddCowSheetState extends State<_AddCowSheet> {
  final _formKey = GlobalKey<FormState>();
  final _tagController = TextEditingController();
  final _nameController = TextEditingController();

  // Question 1: Has she given birth before? (1 = Yes / Adult, 0 = No / Heifer)
  int _hasLactatedBefore = 1;
  // Question 2: Selected state ('MILKING', 'PREGNANT', 'DRY', 'HEIFER', 'BRED_HEIFER')
  String _selectedStatus = 'MILKING';

  // Gestation input mode: 'DATE' (Calendar) vs 'AGE' (Wheel picker)
  String _gestationInputMode = 'DATE';
  DateTime? _matingDate;
  int _gestationMonth = 1;
  int _gestationDay = 0;

  bool _saving = false;
  String? _tagError;
  int _ageYears = 0;
  int _ageMonths = 0;
  int _ageDays = 0;

  @override
  void dispose() {
    _tagController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _onLactationChanged(int value) {
    setState(() {
      _hasLactatedBefore = value;
      if (value == 1) {
        if (_selectedStatus == 'HEIFER' || _selectedStatus == 'BRED_HEIFER') {
          _selectedStatus = 'MILKING';
        }
      } else {
        if (_selectedStatus == 'MILKING' || _selectedStatus == 'PREGNANT') {
          _selectedStatus = 'HEIFER';
        } else if (_selectedStatus == 'DRY') {
          // Stays DRY (Dry Heifer)
        }
      }
      if (!isPregnantOrDry) {
        _matingDate = null;
      }
    });
  }

  bool get isPregnantOrDry =>
      _selectedStatus == 'PREGNANT' ||
      _selectedStatus == 'BRED_HEIFER' ||
      _selectedStatus == 'DRY';

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    DateTime? finalMatingDate = _matingDate;
    int isConfirmed = 0;
    String? method;

    if (isPregnantOrDry) {
      if (_gestationInputMode == 'AGE') {
        // Mode 2: Calculate from Gestation Age Wheel Picker
        final double exactDays =
            ((_gestationMonth - 1) * 30.44) +
            (_gestationDay > 0 ? _gestationDay - 1 : 0);
        final int elapsedDays = exactDays.round();
        final now = DateTime.now();
        final todayMidnight = DateTime(now.year, now.month, now.day);
        finalMatingDate = todayMidnight.subtract(Duration(days: elapsedDays));
        isConfirmed = 1;
        method = 'VET';
      } else if (finalMatingDate == null) {
        AppToast.showError(
          context,
          'Please select a Mating Date or Gestation Age.',
        );
        return;
      }
    } else {
      finalMatingDate = null;
    }

    // ── Observation-window guard ──────────────────────────────────────────
    // When a pregnant/bred-heifer cow is added with a recent mating date
    // (≤28 days) and the pregnancy is NOT yet confirmed (i.e. DATE mode,
    // not AGE mode), route her through the same observation window that
    // recordMating() uses — status becomes PENDING_CONFIRMATION.
    String effectiveStatus = _selectedStatus;
    if (isPregnantOrDry &&
        _selectedStatus != 'DRY' &&
        isConfirmed == 0 &&
        finalMatingDate != null) {
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      final daysSince = todayMidnight.difference(finalMatingDate).inDays;
      if (daysSince <= 28) {
        effectiveStatus = 'PENDING_CONFIRMATION';
      }
    }

    final tagText = _tagController.text.trim();
    final cowProvider = Provider.of<CowProvider>(context, listen: false);

    final exists = cowProvider.isTagTaken(tagText);
    if (exists) {
      setState(() => _tagError = 'Tag "$tagText" is already in use.');
      return;
    } else {
      setState(() => _tagError = null);
    }

    setState(() => _saving = true);

    String? estimatedBirthDateStr;
    if (_ageYears > 0 || _ageMonths > 0 || _ageDays > 0) {
      final today = DateTime.now();
      final birthDate = DateTime(
        today.year - _ageYears,
        today.month - _ageMonths,
        today.day - _ageDays,
      );
      estimatedBirthDateStr =
          "${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}";
    }

    final String matingDateStr = finalMatingDate != null
        ? "${finalMatingDate.year.toString().padLeft(4, '0')}-${finalMatingDate.month.toString().padLeft(2, '0')}-${finalMatingDate.day.toString().padLeft(2, '0')}"
        : '';

    final success = await Provider.of<CowProvider>(context, listen: false)
        .addCow(
          userId: widget.userId,
          tagNumber: _tagController.text.trim(),
          name: _nameController.text.trim().isEmpty
              ? null
              : _nameController.text.trim(),
          status: effectiveStatus,
          matingDate: matingDateStr.isNotEmpty ? matingDateStr : null,
          hasLactatedBefore: _hasLactatedBefore,
          estimatedBirthDate: estimatedBirthDateStr,
          isPregnancyConfirmed: isConfirmed,
          confirmationMethod: method,
        );

    if (!mounted) return;
    setState(() => _saving = false);

    if (success) {
      Navigator.of(context).pop();
      AppToast.showSuccess(
        context,
        'Cow ${_tagController.text.trim()} added to herd.',
      );
    } else {
      final err = Provider.of<CowProvider>(context, listen: false).errorMessage;
      AppToast.showError(context, err ?? 'Failed to add cow.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Container(
      margin: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Add Cow',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 20),

              // Tag field
              TextFormField(
                controller: _tagController,
                onChanged: (val) {
                  if (_tagError != null) setState(() => _tagError = null);
                },
                decoration: InputDecoration(
                  labelText: 'Tag Number *',
                  prefixIcon: const Icon(Icons.tag_rounded, size: 20),
                  errorText: _tagError,
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Tag number is required'
                    : null,
              ),
              const SizedBox(height: 14),

              // Name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name (optional)',
                  prefixIcon: Icon(Icons.pets_rounded, size: 20),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Question 1: Has she given birth before?
              const Text(
                'Has she given birth / calved before? *',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.cardSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(3),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _onLactationChanged(1),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _hasLactatedBefore == 1
                                ? AppColors.cardWhite
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: _hasLactatedBefore == 1
                                ? Border.all(
                                    color: AppColors.deepGreen.withValues(
                                      alpha: 0.3,
                                    ),
                                  )
                                : null,
                            boxShadow: _hasLactatedBefore == 1
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.06,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            'Yes — Given Birth\n(Adult)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _hasLactatedBefore == 1
                                  ? AppColors.deepGreen
                                  : AppColors.textGrey,
                              fontSize: 13,
                              fontWeight: _hasLactatedBefore == 1
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _onLactationChanged(0),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeInOut,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _hasLactatedBefore == 0
                                ? AppColors.cardWhite
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: _hasLactatedBefore == 0
                                ? Border.all(
                                    color: AppColors.deepGreen.withValues(
                                      alpha: 0.3,
                                    ),
                                  )
                                : null,
                            boxShadow: _hasLactatedBefore == 0
                                ? [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.06,
                                      ),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : null,
                          ),
                          child: Text(
                            'No — Never Calved\n(Heifer)',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _hasLactatedBefore == 0
                                  ? AppColors.deepGreen
                                  : AppColors.textGrey,
                              fontSize: 13,
                              fontWeight: _hasLactatedBefore == 0
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Question 2: What is her current state?
              Text(
                _hasLactatedBefore == 1
                    ? 'What is her current adult state? *'
                    : 'What is her current heifer state? *',
                style: const TextStyle(
                  color: AppColors.textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (_hasLactatedBefore == 1) ...[
                Row(
                  children: [
                    Expanded(
                      child: _AddPillChip(
                        label: 'Milking',
                        isSelected: _selectedStatus == 'MILKING',
                        onTap: () => setState(() {
                          _selectedStatus = 'MILKING';
                          _matingDate = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _AddPillChip(
                        label: 'Pregnant',
                        isSelected: _selectedStatus == 'PREGNANT',
                        onTap: () =>
                            setState(() => _selectedStatus = 'PREGNANT'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _AddPillChip(
                        label: 'Dry Cow',
                        isSelected: _selectedStatus == 'DRY',
                        onTap: () => setState(() => _selectedStatus = 'DRY'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: _AddPillChip(
                        label: 'Young Heifer',
                        isSelected: _selectedStatus == 'HEIFER',
                        onTap: () => setState(() {
                          _selectedStatus = 'HEIFER';
                          _matingDate = null;
                        }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _AddPillChip(
                        label: 'Pregnant Heifer',
                        isSelected: _selectedStatus == 'BRED_HEIFER',
                        onTap: () =>
                            setState(() => _selectedStatus = 'BRED_HEIFER'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _AddPillChip(
                        label: 'Dry Heifer',
                        isSelected: _selectedStatus == 'DRY',
                        onTap: () => setState(() => _selectedStatus = 'DRY'),
                      ),
                    ),
                  ],
                ),
              ],

              // Gestation Timing Options (Only shown for Pregnant / Dry selections)
              if (isPregnantOrDry) ...[
                const SizedBox(height: 18),
                const Text(
                  'How do you want to enter pregnancy info? *',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.cardSubtle,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _gestationInputMode = 'DATE'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _gestationInputMode == 'DATE'
                                  ? AppColors.cardWhite
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: _gestationInputMode == 'DATE'
                                  ? Border.all(
                                      color: AppColors.deepGreen.withValues(
                                        alpha: 0.3,
                                      ),
                                    )
                                  : null,
                              boxShadow: _gestationInputMode == 'DATE'
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.06,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              'Exact Mating Date',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _gestationInputMode == 'DATE'
                                    ? AppColors.deepGreen
                                    : AppColors.textGrey,
                                fontSize: 13,
                                fontWeight: _gestationInputMode == 'DATE'
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _gestationInputMode = 'AGE'),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _gestationInputMode == 'AGE'
                                  ? AppColors.cardWhite
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: _gestationInputMode == 'AGE'
                                  ? Border.all(
                                      color: AppColors.deepGreen.withValues(
                                        alpha: 0.3,
                                      ),
                                    )
                                  : null,
                              boxShadow: _gestationInputMode == 'AGE'
                                  ? [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.06,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(
                              'Pregnancy Months &\nDays',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _gestationInputMode == 'AGE'
                                    ? AppColors.deepGreen
                                    : AppColors.textGrey,
                                fontSize: 13,
                                fontWeight: _gestationInputMode == 'AGE'
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (_gestationInputMode == 'DATE') ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: _matingDate ?? DateTime.now(),
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 365),
                        ),
                        lastDate: DateTime.now(),
                      );
                      if (selected != null) {
                        setState(() => _matingDate = selected);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.cardWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE0E0E5)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _selectedStatus == 'DRY'
                                ? Icons.bedtime_outlined
                                : Icons.calendar_today_rounded,
                            size: 20,
                            color: AppColors.textGrey,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedStatus == 'DRY'
                                      ? 'Dry-Off Date / Mating Date *'
                                      : 'Mating Date *',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textGrey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _matingDate != null
                                      ? '${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][_matingDate!.month - 1]} ${_matingDate!.day.toString().padLeft(2, '0')}, ${_matingDate!.year}'
                                      : 'Select Date',
                                  style: TextStyle(
                                    color: _matingDate != null
                                        ? AppColors.textDark
                                        : AppColors.textGrey,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textGrey,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.cardSubtle,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.deepGreen.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Column(
                          children: [
                            const Text(
                              'Month (1-9)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            DropdownButton<int>(
                              value: _gestationMonth,
                              items: List.generate(9, (i) => i + 1)
                                  .map(
                                    (m) => DropdownMenuItem(
                                      value: m,
                                      child: Text('Month $m'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val != null)
                                  setState(() => _gestationMonth = val);
                              },
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            const Text(
                              'Days (0-30)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            DropdownButton<int>(
                              value: _gestationDay,
                              items: List.generate(31, (i) => i)
                                  .map(
                                    (d) => DropdownMenuItem(
                                      value: d,
                                      child: Text('$d Days'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val != null)
                                  setState(() => _gestationDay = val);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 14),
              CowAgePicker(
                initialYears: _ageYears,
                initialMonths: _ageMonths,
                initialDays: _ageDays,
                onAgeChanged: (y, m, d) {
                  _ageYears = y;
                  _ageMonths = m;
                  _ageDays = d;
                },
              ),
              const SizedBox(height: 28),
              // Save button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Cow'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _DeleteCowDialog
// ---------------------------------------------------------------------------
// Soft-deletes a cow. Requires a reason from the dropdown, and a text reason
// if "Other" is selected. Uses min 56x56 buttons.
// ---------------------------------------------------------------------------

// ---------------------------------------------------------------------------
// _DeleteCowDialog
// ---------------------------------------------------------------------------
// Soft-deletes a cow. Requires a reason from the dropdown, and a text reason
// if "Other" is selected. Uses min 56x56 buttons.
// ---------------------------------------------------------------------------

class _DeleteCowDialog extends StatefulWidget {
  final int cowId;
  final String cowName;

  const _DeleteCowDialog({required this.cowId, required this.cowName});

  @override
  State<_DeleteCowDialog> createState() => _DeleteCowDialogState();
}

class _DeleteCowDialogState extends State<_DeleteCowDialog> {
  final _reasons = ['Sold', 'Died', 'Culled', 'Stolen/Lost', 'Other'];
  String? _selectedReason;
  final _otherReasonController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _otherReasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) return;
    if (_selectedReason == 'Other' &&
        _otherReasonController.text.trim().isEmpty) {
      return; // "Other" requires text
    }

    setState(() => _isSubmitting = true);

    final finalReason = _selectedReason == 'Other'
        ? 'Other: ${_otherReasonController.text.trim()}'
        : _selectedReason!;

    final provider = context.read<CowProvider>();
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.id;

    if (userId != null) {
      final success = await provider.deleteCow(
        cowId: widget.cowId,
        userId: userId,
        reason: finalReason,
        cowName: widget.cowName,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cow successfully removed.')),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete cow.')),
          );
        }
      }
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canSubmit =
        _selectedReason != null &&
        (_selectedReason != 'Other' ||
            _otherReasonController.text.trim().isNotEmpty);

    return Dialog(
      backgroundColor: AppColors.cardWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.warningRed,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Remove "${widget.cowName}"?',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This cow will be hidden from the herd and dashboards. This action cannot be undone here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textGrey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            DropdownButtonFormField<String>(
              initialValue: _selectedReason,
              dropdownColor: AppColors.cardWhite,
              style: const TextStyle(color: AppColors.textDark),
              decoration: const InputDecoration(
                labelText: 'Reason for removal *',
              ),
              items: _reasons.map((r) {
                return DropdownMenuItem(value: r, child: Text(r));
              }).toList(),
              onChanged: (val) => setState(() => _selectedReason = val),
            ),
            if (_selectedReason == 'Other') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _otherReasonController,
                style: const TextStyle(color: AppColors.textDark),
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Please specify *',
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textDark,
                      ),
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warningRed,
                        foregroundColor: AppColors.cardWhite,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: (!canSubmit || _isSubmitting) ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.cardWhite,
                              ),
                            )
                          : const Text(
                              'Delete',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helper Widgets for Add Cow Sheet
// ---------------------------------------------------------------------------
class _AddPillChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _AddPillChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.deepGreen : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.deepGreen : const Color(0xFFE0E0E5),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.deepGreen.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textDark,
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
