import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/utils/money_utils.dart';
import '../../data/models/dodi_dashboard_summary.dart';
import '../../data/models/dodi_model.dart';
import '../../presentation/providers/dodi_provider.dart';
import '../../../milk_entry/data/models/ledger_entry_model.dart';
import '../../../milk_entry/presentation/providers/milk_entry_provider.dart';
import '../../../milk_entry/presentation/utils/conflict_resolution_dialog.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../dashboard/presentation/providers/activity_log_provider.dart';
import '../../../../core/constants/app_strings.dart';
import '../widgets/edit_buyer_sheet.dart';

// ---------------------------------------------------------------------------
// DodiDetailScreen
// ---------------------------------------------------------------------------
// Fetches and displays the 4 aggregated financial metrics for a single dodi:
//   1. Total Milk Supplied (kg)
//   2. Grand Total Value (₹)
//   3. Amount Received    (₹)
//   4. Net Amount Due     (₹)
//
// Uses FutureBuilder so the screen shows a loader while the DB query runs.
// All displayed values come from DodiDashboardSummary's UI-only getters
// (the only place division by 100 / 1000 occurs).
// ---------------------------------------------------------------------------

class DodiDetailScreen extends StatefulWidget {
  final DodiModel dodi;
  final bool isArchived;

  const DodiDetailScreen({
    super.key,
    required this.dodi,
    this.isArchived = false,
  });

  @override
  State<DodiDetailScreen> createState() => _DodiDetailScreenState();
}

class _DodiDetailScreenState extends State<DodiDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<DodiProvider>().loadDodiIfNotCached(widget.dodi.id!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold remains static; body watches DodiProvider via Consumer.

    return Consumer<DodiProvider>(
      builder: (context, provider, _) {
        final summary = provider.getCachedSummary(widget.dodi.id!);
        final entries = provider.getCachedLedgerEntries(widget.dodi.id!);
        
        // Get the most up-to-date dodi model from provider (search active dodis, then deleted dodis, then fallback to widget.dodi)
        final updatedDodi = provider.dodis.firstWhere(
          (d) => d.id == widget.dodi.id,
          orElse: () => provider.deletedDodis.firstWhere(
            (d) => d.id == widget.dodi.id,
            orElse: () => widget.dodi,
          ),
        );
        final bool isArchived = widget.isArchived || (updatedDodi.isDeleted == 1);

        return Scaffold(
          backgroundColor: AppColors.bgGrey,
          appBar: AppBar(
            backgroundColor: AppColors.bgGrey,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: AppColors.textDark, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              updatedDodi.name,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.warningRed, size: 22),
                onPressed: () => showBuyerManageModal(context, updatedDodi, isFromDetailScreen: true),
                tooltip: 'Delete / Manage Buyer',
              ),
            ],
          ),
          body: () {
            if (provider.status == DodiStatus.error && (summary == null || entries == null)) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    'Failed to load data:\n${provider.errorMessage}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.warningRed, fontSize: 14),
                  ),
                ),
              );
            }

            if (summary == null || entries == null) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.deepGreen),
              );
            }

            return _DetailBody(dodi: updatedDodi, summary: summary, entries: entries);
          }(),
          floatingActionButton: isArchived
              ? FloatingActionButton.extended(
                  heroTag: 'restore_archived_buyer',
                  onPressed: () async {
                    final authProvider = Provider.of<AuthProvider>(context, listen: false);
                    final userId = authProvider.currentUser?.id ?? 0;
                    final success = await provider.restoreDodi(updatedDodi.id!, userId);
                    if (context.mounted) {
                      if (success) {
                        Navigator.of(context).pop();
                        AppToast.showSuccess(context, '✅ ${updatedDodi.name} restored to active list.');
                      } else {
                        AppToast.showError(context, provider.errorMessage ?? 'Failed to restore buyer.');
                      }
                    }
                  },
                  backgroundColor: AppColors.deepGreen,
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.restore_from_trash_rounded),
                  label: const Text('Restore to Active List'),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FloatingActionButton.extended(
                      heroTag: 'add_milk',
                      onPressed: () => _showAddMilkSheet(context),
                      backgroundColor: AppColors.deepGreen,
                      foregroundColor: Colors.white,
                      icon: const Icon(Icons.water_drop_outlined),
                      label: const Text('Add Milk'),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton.extended(
                      heroTag: 'add_payment',
                      onPressed: () => _showAddPaymentSheet(context),
                      backgroundColor: AppColors.sageTint,
                      foregroundColor: AppColors.deepGreen,
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Add Payment'),
                    ),
                  ],
                ),
        );
      },
    );
  }

  void _showAddMilkSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddMilkEntrySheet(dodi: widget.dodi),
    );
    if (context.mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id ?? 0;
      Provider.of<ActivityLogProvider>(context, listen: false).loadActivities(userId);
    }
  }

  void _showAddPaymentSheet(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddPaymentSheet(dodi: widget.dodi),
    );
    if (context.mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser?.id ?? 0;
      Provider.of<ActivityLogProvider>(context, listen: false).loadActivities(userId);
    }
  }
}

void _showEditBuyerSheet(BuildContext context, DodiModel dodi) async {
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final userId = authProvider.currentUser?.id ?? 0;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => EditBuyerSheet(
      dodi: dodi,
      userId: userId,
    ),
  );
  if (context.mounted) {
    Provider.of<ActivityLogProvider>(context, listen: false).loadActivities(userId);
  }
}

void showBuyerManageModal(BuildContext context, DodiModel dodi, {bool isFromDetailScreen = false}) async {
  final dodiProvider = Provider.of<DodiProvider>(context, listen: false);
  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  final userId = authProvider.currentUser?.id ?? 0;

  final summary = await dodiProvider.fetchSummary(dodi.id!);
  final int duePaise = summary.amountDuePaise;
  final bool isSettled = duePaise == 0;

  if (!context.mounted) return;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: AppColors.cardWhite,
      title: Row(
        children: [
          const Icon(Icons.delete_outline_rounded, color: AppColors.warningRed, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Manage ${dodi.name}',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textDark),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose an action for this buyer:',
            style: TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          // Option 1: Restore (if in Bin) or Move to Bin (if active)
          InkWell(
            onTap: () async {
              Navigator.of(ctx).pop();
              if (dodi.isDeleted == 1) {
                final success = await dodiProvider.restoreDodi(dodi.id!, userId);
                if (context.mounted) {
                  if (success) {
                    if (isFromDetailScreen) {
                      Navigator.of(context).pop();
                    }
                    AppToast.showSuccess(context, '✅ ${dodi.name} restored to active list.');
                  } else {
                    AppToast.showError(context, dodiProvider.errorMessage ?? 'Failed to restore buyer.');
                  }
                }
              } else {
                final success = await dodiProvider.softDeleteDodi(dodi.id!, userId);
                if (context.mounted) {
                  if (success) {
                    if (isFromDetailScreen) {
                      Navigator.of(context).pop();
                    }
                    AppToast.showSuccess(context, '🗑️ ${dodi.name} moved to Bin. You can restore them anytime.');
                  } else {
                    AppToast.showError(context, dodiProvider.errorMessage ?? 'Failed to move to Bin.');
                  }
                }
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.sageTint,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.deepGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    dodi.isDeleted == 1 ? Icons.restore_from_trash_rounded : Icons.archive_outlined,
                    color: AppColors.deepGreen,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dodi.isDeleted == 1 ? 'Restore to Active List' : 'Move to Bin',
                          style: const TextStyle(color: AppColors.deepGreen, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dodi.isDeleted == 1
                              ? 'Restores buyer to active list so you can record new milk entries.'
                              : 'Hides from active lists while keeping financial history safe for restoration.',
                          style: const TextStyle(color: AppColors.textDark, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Option 2: Permanently Delete
          InkWell(
            onTap: () async {
              if (!isSettled) {
                // Block hard delete if account is unsettled
                final dueRs = MoneyUtils.formatPaiseToRupees(duePaise.abs());
                showDialog(
                  context: ctx,
                  builder: (alertCtx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: Row(
                      children: const [
                        Icon(Icons.block_rounded, color: AppColors.warningRed, size: 24),
                        SizedBox(width: 8),
                        Text('Deletion Blocked', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    ),
                    content: Text(
                      'Cannot permanently delete ${dodi.name}. This buyer has an unsettled account balance of ${AppStrings.currency} $dueRs.\n\nPlease settle the balance first or choose "Move to Bin".',
                      style: const TextStyle(fontSize: 14, color: AppColors.textDark),
                    ),
                    actions: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.deepGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () => Navigator.of(alertCtx).pop(),
                        child: const Text('Understand'),
                      ),
                    ],
                  ),
                );
                return;
              }

              // Account is settled! Allow hard deletion after double confirmation
              final confirmHard = await showDialog<bool>(
                context: ctx,
                builder: (hardCtx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: const Text('Permanently Delete?', style: TextStyle(fontWeight: FontWeight.bold)),
                  content: Text(
                    'Are you sure you want to permanently erase ${dodi.name} and all transaction records? This action cannot be undone.',
                    style: const TextStyle(fontSize: 14, color: AppColors.textDark),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(hardCtx).pop(false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.warningRed,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.of(hardCtx).pop(true),
                      child: const Text('Permanently Delete'),
                    ),
                  ],
                ),
              );

              if (confirmHard == true && context.mounted) {
                Navigator.of(ctx).pop();
                final success = await dodiProvider.hardDeleteDodi(dodi.id!, userId);
                if (context.mounted) {
                  if (success) {
                    if (isFromDetailScreen) {
                      Navigator.of(context).pop();
                    }
                    AppToast.showSuccess(context, '🗑️ ${dodi.name} permanently deleted.');
                  } else {
                    AppToast.showError(context, dodiProvider.errorMessage ?? 'Failed to delete buyer.');
                  }
                }
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSettled ? const Color(0xFFFFEBEE) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSettled ? AppColors.warningRed.withValues(alpha: 0.3) : const Color(0xFFE0E0E0),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.delete_forever_rounded,
                    color: isSettled ? AppColors.warningRed : AppColors.textGrey,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Permanently Delete',
                          style: TextStyle(
                            color: isSettled ? AppColors.warningRed : AppColors.textGrey,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isSettled
                              ? 'Account is settled (Rs 0 due). Completely erases buyer from SQLite.'
                              : 'Blocked — Account has pending balance.',
                          style: TextStyle(
                            color: isSettled ? AppColors.textDark : AppColors.textGrey,
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );
}

enum LedgerTimeFilter {
  allTime('All Time'),
  today('Today'),
  sevenDays('7 Days'),
  fifteenDays('15 Days'),
  thisMonth('This Month'),
  lastMonth('Last Month'),
  older('Older');

  final String label;
  const LedgerTimeFilter(this.label);
}

// ---------------------------------------------------------------------------
// _DetailBody — the summary cards + the ledger list
// ---------------------------------------------------------------------------
class _DetailBody extends StatefulWidget {
  final DodiModel dodi;
  final DodiDashboardSummary summary;
  final List<LedgerEntryModel> entries;

  const _DetailBody({required this.dodi, required this.summary, required this.entries});

  @override
  State<_DetailBody> createState() => _DetailBodyState();
}

class _DetailBodyState extends State<_DetailBody> {
  LedgerTimeFilter _selectedFilter = LedgerTimeFilter.allTime;

  List<LedgerEntryModel> _filterEntries() {
    return widget.entries.where((e) => _matchesFilter(e, _selectedFilter)).toList();
  }

  bool _matchesFilter(LedgerEntryModel entry, LedgerTimeFilter filter) {
    if (filter == LedgerTimeFilter.allTime) return true;
    final DateTime? entryDate = DateTime.tryParse(entry.date);
    if (entryDate == null) return true;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final entryDay = DateTime(entryDate.year, entryDate.month, entryDate.day);

    switch (filter) {
      case LedgerTimeFilter.today:
        return entryDay.isAtSameMomentAs(todayStart);
      case LedgerTimeFilter.sevenDays:
        final start = todayStart.subtract(const Duration(days: 6));
        return !entryDay.isBefore(start) && !entryDay.isAfter(todayStart);
      case LedgerTimeFilter.fifteenDays:
        final start = todayStart.subtract(const Duration(days: 14));
        return !entryDay.isBefore(start) && !entryDay.isAfter(todayStart);
      case LedgerTimeFilter.thisMonth:
        final monthStart = DateTime(now.year, now.month, 1);
        return !entryDay.isBefore(monthStart) && !entryDay.isAfter(todayStart);
      case LedgerTimeFilter.lastMonth:
        final prevMonthEnd = DateTime(now.year, now.month, 0);
        final prevMonthStart = DateTime(prevMonthEnd.year, prevMonthEnd.month, 1);
        return !entryDay.isBefore(prevMonthStart) && !entryDay.isAfter(prevMonthEnd);
      case LedgerTimeFilter.older:
        final prevMonthEnd = DateTime(now.year, now.month, 0);
        final prevMonthStart = DateTime(prevMonthEnd.year, prevMonthEnd.month, 1);
        return entryDay.isBefore(prevMonthStart);
      case LedgerTimeFilter.allTime:
        return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filterEntries();
    final isFiltered = _selectedFilter != LedgerTimeFilter.allTime;

    int totalGrams = 0;
    int grandPaise = 0;
    int receivedPaise = 0;

    for (final e in filtered) {
      if (e.type == LedgerEntryType.milkSold) {
        totalGrams += (e.quantityGrams ?? 0);
        grandPaise += e.amountPaise;
      } else if (e.type == LedgerEntryType.paymentReceived) {
        receivedPaise += e.amountPaise.abs();
      }
    }

    final periodDuePaise = grandPaise - receivedPaise;
    final avgRatePaise = totalGrams > 0 ? ((grandPaise * 1000) / totalGrams).round() : 0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryCards(
            dodi: widget.dodi,
            summary: widget.summary,
            isFiltered: isFiltered,
            filterLabel: _selectedFilter.label,
            totalMilkGrams: totalGrams,
            grandTotalPaise: grandPaise,
            amountTakenPaise: receivedPaise,
            periodDuePaise: periodDuePaise,
            avgRatePaise: avgRatePaise,
          ),
          const SizedBox(height: 16),
          _PendingAlertBanner(
            periodDuePaise: periodDuePaise,
            overallDuePaise: widget.summary.amountDuePaise,
            filterLabel: _selectedFilter.label,
          ),
          const SizedBox(height: 24),
          const Text(
            'Ledger Entries',
            style: TextStyle(
              color: AppColors.textDark,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 12),
          // Time Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: LedgerTimeFilter.values.map((f) {
                final selected = _selectedFilter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(f.label),
                    selected: selected,
                    onSelected: (val) {
                      if (val) setState(() => _selectedFilter = f);
                    },
                    selectedColor: AppColors.deepGreen,
                    backgroundColor: AppColors.cardWhite,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : AppColors.textDark,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          _GroupedLedgerList(dodi: widget.dodi, entries: filtered),
        ],
      ),
    );
  }
}

class _PendingAlertBanner extends StatelessWidget {
  final int periodDuePaise;
  final int overallDuePaise;
  final String filterLabel;

  const _PendingAlertBanner({
    required this.periodDuePaise,
    required this.overallDuePaise,
    required this.filterLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (periodDuePaise > 0) {
      final periodDueRs = MoneyUtils.formatPaiseToRupees(periodDuePaise);
      final overallDueRs = MoneyUtils.formatPaiseToRupees(overallDuePaise);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEBEE),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.warningRed.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.warningRed, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ Payment Pending (${AppStrings.currency} $periodDueRs)',
                    style: const TextStyle(
                      color: AppColors.warningRed,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Buyer has ${AppStrings.currency} $periodDueRs pending for $filterLabel (Overall Due: ${AppStrings.currency} $overallDueRs).',
                    style: const TextStyle(color: AppColors.textDark, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (periodDuePaise == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.sageTint,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.deepGreen.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: AppColors.deepGreen, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '✅ Account Settled — Zero pending balance for $filterLabel.',
                style: const TextStyle(color: AppColors.deepGreen, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    } else {
      final advanceRs = MoneyUtils.formatPaiseToRupees(periodDuePaise.abs());
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.sageTint,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.deepGreen.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet_rounded, color: AppColors.deepGreen, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '🟢 Advance Credit: Buyer has paid ${AppStrings.currency} $advanceRs in advance for $filterLabel.',
                style: const TextStyle(color: AppColors.deepGreen, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }
  }
}

class _SummaryCards extends StatelessWidget {
  final DodiModel dodi;
  final DodiDashboardSummary summary;
  final bool isFiltered;
  final String filterLabel;
  final int totalMilkGrams;
  final int grandTotalPaise;
  final int amountTakenPaise;
  final int periodDuePaise;
  final int avgRatePaise;

  const _SummaryCards({
    required this.dodi,
    required this.summary,
    required this.isFiltered,
    required this.filterLabel,
    required this.totalMilkGrams,
    required this.grandTotalPaise,
    required this.amountTakenPaise,
    required this.periodDuePaise,
    required this.avgRatePaise,
  });

  @override
  Widget build(BuildContext context) {
    final displayTotalGrams = isFiltered ? totalMilkGrams : summary.totalMilkGrams;
    final displayGrandPaise = isFiltered ? grandTotalPaise : summary.grandTotalPaise;
    final displayTakenPaise = isFiltered ? amountTakenPaise : summary.amountTakenPaise;
    final displayDuePaise = isFiltered ? periodDuePaise : summary.amountDuePaise;

    final totalKg = MoneyUtils.formatGramsToKg(displayTotalGrams);
    final grandTotal = MoneyUtils.formatPaiseToRupees(displayGrandPaise);
    final amountTaken = MoneyUtils.formatPaiseToRupees(displayTakenPaise);
    final amountDue = MoneyUtils.formatPaiseToRupees(displayDuePaise);
    final avgRate = MoneyUtils.formatPaiseToRupees(isFiltered && avgRatePaise > 0 ? avgRatePaise : dodi.defaultRatePaise);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (dodi.isDeleted == 1) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFB74D)),
            ),
            child: Row(
              children: const [
                Icon(Icons.archive_outlined, color: Color(0xFFE65100), size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '📦 Archived Buyer (In Bin) — View Only. Tap Restore to re-activate.',
                    style: TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        // Dodi header chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.sageTint,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.deepGreen,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dodi.name,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (dodi.phone != null && dodi.phone!.isNotEmpty)
                      GestureDetector(
                        onTap: () async {
                          final phoneNumber = dodi.phone!;
                          final sanitizedNumber = phoneNumber.replaceAll(RegExp(r'\s+\b|\b\s+'), '');
                          final Uri launchUri = Uri(
                            scheme: 'tel',
                            path: sanitizedNumber,
                          );
                          try {
                            if (await canLaunchUrl(launchUri)) {
                              await launchUrl(launchUri);
                            }
                          } catch (e) {
                            debugPrint('Native dialer exception: $e');
                          }
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.phone, size: 14, color: AppColors.deepGreen),
                            const SizedBox(width: 4),
                            Text(
                              dodi.phone!,
                              style: const TextStyle(
                                color: AppColors.deepGreen,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: AppColors.textGrey, size: 20),
                onPressed: () => _showEditBuyerSheet(context, dodi),
                constraints: const BoxConstraints(),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.sageTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${AppStrings.currency}$avgRate/${AppStrings.weightUnit}',
                  style: const TextStyle(
                    color: AppColors.deepGreen,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Account Summary',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            if (isFiltered)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.deepGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  filterLabel,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
          ],
        ),

        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Total Milk',
                value: '$totalKg ${AppStrings.weightUnit}',
                icon: Icons.water_drop_rounded,
                iconColor: const Color(0xFF4FC3F7),
                iconBg: const Color(0xFFE1F5FE),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _MetricCard(
                label: 'Grand Total',
                value: '${AppStrings.currency}$grandTotal',
                icon: Icons.receipt_long_rounded,
                iconColor: const Color(0xFF66BB6A),
                iconBg: const Color(0xFFE8F5E9),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Amount Received',
                value: '${AppStrings.currency}$amountTaken',
                icon: Icons.payments_rounded,
                iconColor: const Color(0xFF7986CB),
                iconBg: const Color(0xFFE8EAF6),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _MetricCard(
                label: 'Amount Due',
                value: '${AppStrings.currency}$amountDue',
                icon: Icons.account_balance_rounded,
                iconColor: displayDuePaise > 0 ? AppColors.warningRed : AppColors.deepGreen,
                iconBg: displayDuePaise > 0 ? const Color(0xFFFFEBEE) : AppColors.sageTint,
                valueColor: displayDuePaise > 0 ? AppColors.warningRed : AppColors.deepGreen,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _MetricCard — single large-number stat card
// ---------------------------------------------------------------------------
class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color? valueColor;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 110),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),

          const SizedBox(height: 14),

          // Label
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textGrey,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),

          // The big value — using large bold text, wrapped in FittedBox
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AppColors.textDark,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DailyLedgerSummary Data Model
// ---------------------------------------------------------------------------
class DailyLedgerSummary {
  final String date;
  int totalMilkGrams = 0;
  int totalAmountPaise = 0;
  final List<LedgerEntryModel> entries = [];
  
  DailyLedgerSummary(this.date);
}

// ---------------------------------------------------------------------------
// _GroupedLedgerList
// ---------------------------------------------------------------------------
class _GroupedLedgerList extends StatelessWidget {
  final DodiModel dodi;
  final List<LedgerEntryModel> entries;
  
  const _GroupedLedgerList({required this.dodi, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'No entries yet.',
            style: TextStyle(color: AppColors.textGrey, fontSize: 16),
          ),
        ),
      );
    }

    // Group items by date, separating milk sold from payments
    final Map<String, DailyLedgerSummary> milkGrouped = {};
    final Map<String, List<LedgerEntryModel>> paymentGrouped = {};

    for (var entry in entries) {
      if (entry.type == LedgerEntryType.milkSold) {
        final summary = milkGrouped.putIfAbsent(entry.date, () => DailyLedgerSummary(entry.date));
        summary.entries.add(entry);
        summary.totalMilkGrams += entry.quantityGrams ?? 0;
        summary.totalAmountPaise += entry.amountPaise;
      } else {
        paymentGrouped.putIfAbsent(entry.date, () => []).add(entry);
      }
    }

    // Combine all unique dates sorted descending
    final allDates = {...milkGrouped.keys, ...paymentGrouped.keys}.toList()..sort((a, b) => b.compareTo(a));

    final List<Widget> timelineWidgets = [];

    for (final date in allDates) {
      final milkSummary = milkGrouped[date];
      final dayPayments = paymentGrouped[date];

      if (milkSummary != null && milkSummary.entries.isNotEmpty) {
        timelineWidgets.add(_DailySummaryCard(dodi: dodi, summary: milkSummary));
      }

      if (dayPayments != null && dayPayments.isNotEmpty) {
        for (final pay in dayPayments) {
          timelineWidgets.add(_StandalonePaymentCard(dodi: dodi, entry: pay));
        }
      }
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: timelineWidgets.length,
      separatorBuilder: (ctx, i) => const SizedBox(height: 12),
      itemBuilder: (context, index) => timelineWidgets[index],
    );
  }
}

class _StandalonePaymentCard extends StatelessWidget {
  final DodiModel dodi;
  final LedgerEntryModel entry;

  const _StandalonePaymentCard({required this.dodi, required this.entry});

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMMM d, yyyy').format(DateTime.parse(entry.date));
    final isPayment = entry.type == LedgerEntryType.paymentReceived;
    final amountRs = MoneyUtils.formatPaiseToRupees(entry.amountPaise.abs());
    final label = isPayment ? 'Payment Received' : 'Advance Taken';
    final sign = isPayment ? '-' : '+';
    final color = isPayment ? const Color(0xFF2E7D32) : AppColors.warningRed;

    return InkWell(
      onLongPress: () => _confirmDeleteEntry(context, entry),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isPayment ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isPayment ? Icons.account_balance_wallet_rounded : Icons.money_off_rounded,
                        color: color,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00522A),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    dateStr,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'COMPLETED',
                    style: TextStyle(color: Color(0xFF2E7D32), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '$sign ${AppStrings.currency} $amountRs',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteEntry(BuildContext context, LedgerEntryModel entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: const Text('Are you sure you want to delete this payment entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              final userId = authProvider.currentUser?.id ?? 0;
              await Provider.of<DodiProvider>(context, listen: false).deleteLedgerEntry(
                entryId: entry.id!,
                dodiId: dodi.id!,
                userId: userId,
              );
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.warningRed)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _DailySummaryCard
// ---------------------------------------------------------------------------
class _DailySummaryCard extends StatefulWidget {
  final DodiModel dodi;
  final DailyLedgerSummary summary;

  const _DailySummaryCard({required this.dodi, required this.summary});

  @override
  State<_DailySummaryCard> createState() => _DailySummaryCardState();
}

class _DailySummaryCardState extends State<_DailySummaryCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMMM d, yyyy').format(DateTime.parse(widget.summary.date));
    final totalKg = (widget.summary.totalMilkGrams / 1000).toStringAsFixed(1);
    final totalRs = (widget.summary.totalAmountPaise / 100).toStringAsFixed(2);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Component (Tap to toggle accordion)
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: _isExpanded
                ? const BorderRadius.vertical(top: Radius.circular(16))
                : BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.sageTint.withValues(alpha: 0.5),
                borderRadius: _isExpanded
                    ? const BorderRadius.vertical(top: Radius.circular(16))
                    : BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  // Top Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            color: AppColors.deepGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.water_drop_rounded, color: AppColors.deepGreen, size: 16),
                          const SizedBox(width: 8),
                          const Text('Milk Sold', style: TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700, fontSize: 15)),
                        ],
                      ),
                      Row(
                        children: [
                          InkWell(
                            onTap: () => _showEditDailyDialog(context, widget.dodi, widget.summary),
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.all(4.0),
                              child: Icon(Icons.edit, size: 18, color: AppColors.deepGreen),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00522A),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today, color: Colors.white, size: 12),
                                const SizedBox(width: 6),
                                Text(dateStr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                // Sub-Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text('Total: $totalKg Kg', style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text('Total: ${AppStrings.currency}$totalRs', style: const TextStyle(color: AppColors.deepGreen, fontWeight: FontWeight.w800, fontSize: 14)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
          
        // Body Component (Entries) — Animated Accordion
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity, height: 0),
          secondChild: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: _buildGroupedEntries(context),
            ),
          ),
          crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
      ],
    ),
  );
}

  List<Widget> _buildGroupedEntries(BuildContext context) {
    final morning = widget.summary.entries.where((e) => e.type == LedgerEntryType.milkSold && e.session == 'MORNING').toList();
    final evening = widget.summary.entries.where((e) => e.type == LedgerEntryType.milkSold && e.session == 'EVENING').toList();
    final payments = widget.summary.entries.where((e) => e.type != LedgerEntryType.milkSold).toList();

    final List<Widget> widgets = [];

    // Morning Session
    if (morning.isNotEmpty) {
      widgets.add(_buildSessionGroup(context, sessionLabel: '🌅 Morning', entries: morning));
    }

    // Evening Session
    if (evening.isNotEmpty) {
      if (widgets.isNotEmpty) widgets.add(const Divider(height: 16, color: Color(0xFFEEEEEE)));
      widgets.add(_buildSessionGroup(context, sessionLabel: '🌃 Evening', entries: evening));
    }

    // Financial Transactions (Payments / Advances)
    if (payments.isNotEmpty) {
      if (widgets.isNotEmpty) widgets.add(const Divider(height: 16, color: Color(0xFFEEEEEE)));
      for (final pay in payments) {
        widgets.add(
          InkWell(
            onLongPress: () => _confirmDelete(context, pay),
            borderRadius: BorderRadius.circular(8),
            child: _buildPaymentRow(context, pay),
          ),
        );
      }
    }

    return widgets;
  }

  Widget _buildSessionGroup(BuildContext context, {required String sessionLabel, required List<LedgerEntryModel> entries}) {
    if (entries.length == 1) {
      final entry = entries.first;
      final tag = (entry.loadTag != null && entry.loadTag!.isNotEmpty) ? entry.loadTag! : null;      return InkWell(
        onLongPress: () => _confirmDelete(context, entry),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(sessionLabel, style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700, fontSize: 14)),
                  if (tag != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.sageTint,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(tag, style: const TextStyle(color: AppColors.deepGreen, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
              _buildEntryValueColumn(entry),
            ],
          ),
        ),
      );
    }

    // Multiple loads for this session!
    int groupGrams = 0;
    int groupPaise = 0;
    for (final e in entries) {
      groupGrams += (e.quantityGrams ?? 0);
      groupPaise += e.amountPaise;
    }

    final totalKg = MoneyUtils.formatGramsToKg(groupGrams);
    final totalRs = MoneyUtils.formatPaiseToRupees(groupPaise);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Multi-load session header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(sessionLabel, style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${entries.length} loads',
                      style: const TextStyle(color: Color(0xFF1565C0), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              Text(
                'Total: $totalKg Kg | ${AppStrings.currency} $totalRs',
                style: const TextStyle(color: AppColors.deepGreen, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ],
          ),
        ),
        // Indented multi-load sub-items
        ...entries.asMap().entries.map((item) {
          final index = item.key;
          final entry = item.value;
          final tag = (entry.loadTag != null && entry.loadTag!.isNotEmpty) ? entry.loadTag! : 'Load ${index + 1}';

          return InkWell(
            onLongPress: () => _confirmDelete(context, entry),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.subdirectory_arrow_right_rounded, size: 16, color: AppColors.textGrey),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.sageTint,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.deepGreen.withValues(alpha: 0.2), width: 1),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(color: AppColors.deepGreen, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  _buildEntryValueColumn(entry),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildEntryValueColumn(LedgerEntryModel entry) {
    final qtyKg = MoneyUtils.formatGramsToKg(entry.quantityGrams ?? 0);
    final rateRs = MoneyUtils.formatPaiseToRupees(entry.ratePaise ?? 0);
    final revRs = MoneyUtils.formatPaiseToRupees(entry.amountPaise);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$qtyKg Kg × ${AppStrings.currency}$rateRs',
          style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w600, fontSize: 13),
        ),
        Text(
          '${AppStrings.currency} $revRs',
          style: const TextStyle(color: AppColors.deepGreen, fontWeight: FontWeight.w700, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildPaymentRow(BuildContext context, LedgerEntryModel entry) {
    final isPayment = entry.type == LedgerEntryType.paymentReceived;
    final amountRs = MoneyUtils.formatPaiseToRupees(entry.amountPaise.abs());
    final label = isPayment ? 'Payment Received' : 'Advance Taken';
    final color = isPayment ? const Color(0xFF2E7D32) : AppColors.warningRed;
    final sign = entry.amountPaise > 0 ? '+' : '-';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(isPayment ? Icons.payments_rounded : Icons.money_off_rounded, color: color, size: 18),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('COMPLETED', style: TextStyle(color: Color(0xFF2E7D32), fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          Text(
            '$sign ${AppStrings.currency} $amountRs',
            style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, LedgerEntryModel entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry?'),
        content: const Text('Are you sure you want to delete this ledger entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final authProvider = Provider.of<AuthProvider>(context, listen: false);
              final userId = authProvider.currentUser?.id ?? 0;
              await Provider.of<DodiProvider>(context, listen: false).deleteLedgerEntry(
                entryId: entry.id!,
                dodiId: widget.dodi.id!,
                userId: userId,
              );
              if (context.mounted) {
                Provider.of<MilkEntryProvider>(context, listen: false).fetchTodaysTotalMilk();
                Provider.of<ActivityLogProvider>(context, listen: false).loadActivities(userId);
              }
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.warningRed)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _AddPaymentSheet
// ---------------------------------------------------------------------------
class _AddPaymentSheet extends StatefulWidget {
  final DodiModel dodi;
  const _AddPaymentSheet({required this.dodi});

  @override
  State<_AddPaymentSheet> createState() => _AddPaymentSheetState();
}

class _AddPaymentSheetState extends State<_AddPaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final String selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    final success = await Provider.of<DodiProvider>(context, listen: false).recordPayment(
      dodiId: widget.dodi.id!,
      amountString: _amountController.text.trim(),
      date: selectedDateStr,
      userId: widget.dodi.userId,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (success) {
      Navigator.of(context).pop();
      AppToast.showSuccess(context, 'Payment recorded successfully.');
    } else {
      final error = Provider.of<DodiProvider>(context, listen: false).errorMessage;
      AppToast.showError(context, error ?? 'Failed to record payment.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
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
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Receive Payment',
                    style: TextStyle(color: AppColors.textDark, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4),
                  ),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.sageTint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.deepGreen),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('MMM d, yyyy').format(_selectedDate),
                            style: const TextStyle(color: AppColors.deepGreen, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _amountController,
                decoration: InputDecoration(
                  labelText: 'Amount (${AppStrings.currency}) *',
                  prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Amount is required';
                  if (double.tryParse(v.trim()) == null) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  child: _saving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : const Text('Save Payment'),
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
// _AddMilkEntrySheet
// ---------------------------------------------------------------------------
class _AddMilkEntrySheet extends StatefulWidget {
  final DodiModel dodi;
  const _AddMilkEntrySheet({required this.dodi});

  @override
  State<_AddMilkEntrySheet> createState() => _AddMilkEntrySheetState();
}

class _AddMilkEntrySheetState extends State<_AddMilkEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _rateController = TextEditingController();
  final _loadTagController = TextEditingController(text: 'Load 1');
  DateTime _selectedDate = DateTime.now();
  String _selectedSession = 'MORNING';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _rateController.text = MoneyUtils.formatPaiseToRupees(widget.dodi.defaultRatePaise);
    final hour = DateTime.now().hour;
    if (hour >= 12) {
      _selectedSession = 'EVENING';
    }
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _rateController.dispose();
    _loadTagController.dispose();
    super.dispose();
  }

  void _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final String entryDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final String session = _selectedSession;
    final int ratePaise = MoneyUtils.rupeesToPaise(_rateController.text.trim());
    final quantityString = _quantityController.text.trim();
    final loadTag = _loadTagController.text.trim().isEmpty ? 'Load 1' : _loadTagController.text.trim();

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final milkProvider = Provider.of<MilkEntryProvider>(context, listen: false);
    final userId = authProvider.currentUser!.id!;

    // Conflict Check
    final existingEntry = await milkProvider.checkExistingEntry(
      dodiId: widget.dodi.id!,
      session: session,
      date: entryDateStr,
    );

    if (existingEntry != null && mounted) {
      setState(() => _saving = false);
      final action = await showDuplicateShiftConflictDialog(
        context: context,
        existingEntry: existingEntry,
        newQuantity: quantityString,
        session: session,
      );

      if (action == null || action == ConflictResolutionAction.cancel) {
        return;
      }

      setState(() => _saving = true);
      
      bool success = false;
      if (action == ConflictResolutionAction.saveAsSeparate) {
        success = await milkProvider.recordMilkEntry(
          userId: userId,
          buyerName: widget.dodi.name,
          dodiId: widget.dodi.id!,
          quantityString: quantityString,
          ratePaise: ratePaise,
          session: session,
          date: entryDateStr,
          loadTag: loadTag,
        );
      } else if (action == ConflictResolutionAction.replaceExisting) {
        success = await milkProvider.updateMilkEntry(
          entryId: existingEntry.id!,
          userId: userId,
          buyerName: widget.dodi.name,
          dodiId: widget.dodi.id!,
          quantityString: quantityString,
          ratePaise: ratePaise,
          session: session,
          date: entryDateStr,
          loadTag: loadTag,
        );
      } else if (action == ConflictResolutionAction.mergeAndHarmonize) {
        final existingQtyGrams = existingEntry.quantityGrams ?? 0;
        final newQtyGrams = ((double.tryParse(quantityString) ?? 0.0) * 1000).round();
        final totalQtyGrams = existingQtyGrams + newQtyGrams;
        final totalQtyString = (totalQtyGrams / 1000).toStringAsFixed(1);
        
        final existingAmountPaise = existingEntry.amountPaise;
        final newAmountPaise = ((newQtyGrams * ratePaise) / 1000).round();
        final totalAmountPaise = existingAmountPaise + newAmountPaise;
        
        final newRatePaise = totalQtyGrams > 0 ? ((totalAmountPaise * 1000) / totalQtyGrams).round() : ratePaise;

        success = await milkProvider.updateMilkEntry(
          entryId: existingEntry.id!,
          userId: userId,
          buyerName: widget.dodi.name,
          dodiId: widget.dodi.id!,
          quantityString: totalQtyString,
          ratePaise: newRatePaise,
          session: session,
          date: entryDateStr,
          loadTag: loadTag,
        );
      }

      if (!mounted) return;
      setState(() => _saving = false);

      if (success) {
        Provider.of<DodiProvider>(context, listen: false).refreshDodi(widget.dodi.id!);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✓ Milk entry saved successfully.', style: TextStyle(fontWeight: FontWeight.w600)),
            backgroundColor: AppColors.deepGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      } else {
        final err = milkProvider.errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err ?? 'Failed to save milk entry.'),
            backgroundColor: AppColors.warningRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
      return;
    }

    final success = await milkProvider.recordMilkEntry(
      userId: userId,
      buyerName: widget.dodi.name,
      dodiId: widget.dodi.id!,
      quantityString: quantityString,
      ratePaise: ratePaise,
      session: session,
      date: entryDateStr,
      loadTag: loadTag,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (success) {
      Provider.of<DodiProvider>(context, listen: false).refreshDodi(widget.dodi.id!);
      
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✓ Milk entry recorded successfully.', style: TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: AppColors.deepGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } else {
      final err = milkProvider.errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err ?? 'Failed to record milk entry.'),
          backgroundColor: AppColors.warningRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mq.viewInsets.bottom),
      child: Container(
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
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: const Color(0xFFE0E0E0), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add Milk Entry',
                    style: TextStyle(color: AppColors.textDark, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.4),
                  ),
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.sageTint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.deepGreen),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('MMM d, yyyy').format(_selectedDate),
                            style: const TextStyle(color: AppColors.deepGreen, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity (kg) *',
                      prefixIcon: Icon(Icons.water_drop_outlined, size: 20),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (double.tryParse(v.trim()) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextFormField(
                    controller: _rateController,
                    decoration: InputDecoration(
                      labelText: 'Rate (${AppStrings.currency}/L) *',
                      prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (double.tryParse(v.trim()) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedSession,
                    decoration: AppTheme.filledInputDecoration(
                      labelText: 'Session',
                      prefixIcon: const Icon(Icons.access_time_rounded, size: 20),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'MORNING', child: Text('Morning')),
                      DropdownMenuItem(value: 'EVENING', child: Text('Evening')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedSession = val);
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: TextFormField(
                    controller: _loadTagController,
                    decoration: AppTheme.filledInputDecoration(
                      labelText: 'Load Tag *',
                      prefixIcon: const Icon(Icons.label_outline_rounded, size: 20),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.deepGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                child: _saving
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                    : const Text('Save Milk Entry'),
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
// _EditDailyLedgerDialog
// ---------------------------------------------------------------------------
Future<void> _showEditDailyDialog(BuildContext context, DodiModel dodi, DailyLedgerSummary summary) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _EditDailyLedgerDialog(dodi: dodi, summary: summary),
  );
}

class _EditDailyLedgerDialog extends StatefulWidget {
  final DodiModel dodi;
  final DailyLedgerSummary summary;

  const _EditDailyLedgerDialog({required this.dodi, required this.summary});

  @override
  State<_EditDailyLedgerDialog> createState() => _EditDailyLedgerDialogState();
}

class _EditDailyLedgerDialogState extends State<_EditDailyLedgerDialog> {
  final _formKey = GlobalKey<FormState>();
  
  late DateTime _selectedDate;
  
  final _mQtyCtrl = TextEditingController();
  final _mRateCtrl = TextEditingController();
  LedgerEntryModel? _morningEntry;

  final _eQtyCtrl = TextEditingController();
  final _eRateCtrl = TextEditingController();
  LedgerEntryModel? _eveningEntry;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.parse(widget.summary.date);

    for (var entry in widget.summary.entries) {
      if (entry.type == LedgerEntryType.milkSold) {
        if (entry.session == 'MORNING') {
          _morningEntry = entry;
          if (entry.quantityGrams != null) _mQtyCtrl.text = (entry.quantityGrams! / 1000).toStringAsFixed(1);
          if (entry.ratePaise != null) _mRateCtrl.text = (entry.ratePaise! / 100).toStringAsFixed(2);
        } else if (entry.session == 'EVENING') {
          _eveningEntry = entry;
          if (entry.quantityGrams != null) _eQtyCtrl.text = (entry.quantityGrams! / 1000).toStringAsFixed(1);
          if (entry.ratePaise != null) _eRateCtrl.text = (entry.ratePaise! / 100).toStringAsFixed(2);
        }
      }
    }
  }

  @override
  void dispose() {
    _mQtyCtrl.dispose();
    _mRateCtrl.dispose();
    _eQtyCtrl.dispose();
    _eRateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<bool> _confirmDeleteSession(String sessionName) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $sessionName Session?'),
        content: Text('You have cleared the $sessionName session. Would you like to permanently delete this entry?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: AppColors.warningRed)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    final mQtyEmpty = _mQtyCtrl.text.trim().isEmpty;
    final mRateEmpty = _mRateCtrl.text.trim().isEmpty;
    final eQtyEmpty = _eQtyCtrl.text.trim().isEmpty;
    final eRateEmpty = _eRateCtrl.text.trim().isEmpty;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final milkProvider = Provider.of<MilkEntryProvider>(context, listen: false);
    final dodiProvider = Provider.of<DodiProvider>(context, listen: false);

    // Guard: deleting morning
    if (_morningEntry != null && (mQtyEmpty || mRateEmpty)) {
      final confirm = await _confirmDeleteSession('Morning');
      if (!confirm) return;
    }

    // Guard: deleting evening
    if (_eveningEntry != null && (eQtyEmpty || eRateEmpty)) {
      final confirm = await _confirmDeleteSession('Evening');
      if (!confirm) return;
    }

    if (!mounted) return;
    setState(() => _isSaving = true);
    final userId = authProvider.currentUser?.id ?? 0;
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    try {
      // Process Morning
      if (_morningEntry != null && (mQtyEmpty || mRateEmpty)) {
        await dodiProvider.deleteLedgerEntry(entryId: _morningEntry!.id!, dodiId: widget.dodi.id!, userId: userId);
      } else if (!mQtyEmpty && !mRateEmpty) {
        final ratePaise = (double.parse(_mRateCtrl.text.trim()) * 100).round();
        if (_morningEntry != null) {
          await milkProvider.updateMilkEntry(
            entryId: _morningEntry!.id!,
            dodiId: widget.dodi.id!,
            userId: userId,
            date: dateStr,
            session: 'MORNING',
            quantityString: _mQtyCtrl.text.trim(),
            ratePaise: ratePaise,
            buyerName: widget.dodi.name,
          );
        } else {
          await milkProvider.recordMilkEntry(
            dodiId: widget.dodi.id!,
            userId: userId,
            date: dateStr,
            session: 'MORNING',
            quantityString: _mQtyCtrl.text.trim(),
            ratePaise: ratePaise,
            buyerName: widget.dodi.name,
          );
        }
      }

      // Process Evening
      if (_eveningEntry != null && (eQtyEmpty || eRateEmpty)) {
        await dodiProvider.deleteLedgerEntry(entryId: _eveningEntry!.id!, dodiId: widget.dodi.id!, userId: userId);
      } else if (!eQtyEmpty && !eRateEmpty) {
        final ratePaise = (double.parse(_eRateCtrl.text.trim()) * 100).round();
        if (_eveningEntry != null) {
          await milkProvider.updateMilkEntry(
            entryId: _eveningEntry!.id!,
            dodiId: widget.dodi.id!,
            userId: userId,
            date: dateStr,
            session: 'EVENING',
            quantityString: _eQtyCtrl.text.trim(),
            ratePaise: ratePaise,
            buyerName: widget.dodi.name,
          );
        } else {
          await milkProvider.recordMilkEntry(
            dodiId: widget.dodi.id!,
            userId: userId,
            date: dateStr,
            session: 'EVENING',
            quantityString: _eQtyCtrl.text.trim(),
            ratePaise: ratePaise,
            buyerName: widget.dodi.name,
          );
        }
      }

      await dodiProvider.refreshDodi(widget.dodi.id!);
      
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save entries: $e')));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateDisplay = DateFormat('MMMM d, yyyy').format(_selectedDate);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Edit Entries', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textDark)),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textGrey),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Date Chip
              Center(
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00522A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Text(dateDisplay, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Morning Session
              const Text('🌅 Morning Session', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.deepGreen, fontSize: 15)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _mQtyCtrl,
                      decoration: const InputDecoration(labelText: 'Quantity (Kg)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty && double.tryParse(val) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _mRateCtrl,
                      decoration: const InputDecoration(labelText: 'Rate (Rs)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty && double.tryParse(val) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              // Evening Session
              const Text('🌃 Evening Session', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.deepGreen, fontSize: 15)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _eQtyCtrl,
                      decoration: const InputDecoration(labelText: 'Quantity (Kg)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty && double.tryParse(val) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _eRateCtrl,
                      decoration: const InputDecoration(labelText: 'Rate (Rs)'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (val) {
                        if (val != null && val.trim().isNotEmpty && double.tryParse(val) == null) return 'Invalid';
                        return null;
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Changes', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
