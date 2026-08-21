import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_toast.dart';
import '../../core/utils/money_utils.dart';
import '../auth/presentation/providers/auth_provider.dart';
import '../cows/presentation/providers/cow_provider.dart';
import '../cows/presentation/pages/cows_screen.dart';
import '../cows/presentation/widgets/cow_age_picker.dart';
import '../cows/presentation/models.dart' as ui_models;
import '../dashboard/presentation/pages/dashboard_screen.dart';
import '../dashboard/presentation/pages/activity_log_screen.dart';
import '../dodi_ledger/presentation/pages/dodi_ledger_screen.dart';
import '../dodi_ledger/presentation/pages/dodi_detail_screen.dart';
import '../dodi_ledger/presentation/providers/dodi_provider.dart';
import '../milk_entry/presentation/providers/milk_entry_provider.dart';
import '../../core/routing/app_router.dart';
import '../dashboard/presentation/utils/dashboard_refresh_coordinator.dart';

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

import '../dashboard/presentation/providers/activity_log_provider.dart';

class AppShell extends StatefulWidget {
  /// The DB primary key of the currently logged-in farmer.
  final int userId;
  final int initialIndex;

  const AppShell({
    super.key,
    required this.userId,
    this.initialIndex = 0,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
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
      Provider.of<MilkEntryProvider>(context, listen: false).fetchTodaysTotalMilk();
    }
  }

  // ── Navigation handler ────────────────────────────────────────────────────

  void _onNavTap(int index) async {
    if (index == 1) {
      if (_isMilkEntryOpen) return;
      _isMilkEntryOpen = true;
      final result = await AppRouter.pushMilkEntry(context);
      _isMilkEntryOpen = false;
      if (result != null && mounted) {
        setState(() => _currentIndex = result);
      }
      return;
    }
    if (index == _currentIndex) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  // ── Dodi card tap → DodiDetailScreen ─────────────────────────────────────

  void _onDodiCardTap(String dodiIdStr) {
    final dodiProvider = Provider.of<DodiProvider>(context, listen: false);
    final dodiId = int.tryParse(dodiIdStr);
    if (dodiId == null) return;
    
    // Search active buyers first; fallback to archived buyers in Bin
    final dodi = dodiProvider.dodis.where((d) => d.id == dodiId).firstOrNull ??
                 dodiProvider.deletedDodis.where((d) => d.id == dodiId).firstOrNull;
    if (dodi == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DodiDetailScreen(dodi: dodi),
      ),
    );
  }

  void _onDodiCardLongPress(String dodiIdStr) async {
    final dodiId = int.tryParse(dodiIdStr);
    if (dodiId == null) return;

    final dodiProvider = Provider.of<DodiProvider>(context, listen: false);
    final dodi = dodiProvider.dodis.where((d) => d.id == dodiId).firstOrNull ??
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
    final cow = cowProvider.cows.firstWhere((c) => c.id == cowId);
    final cowName = (cow.name != null && cow.name!.trim().isNotEmpty) ? cow.name! : cow.tagNumber;

    final daysMated = cowProvider.getDaysSinceMating(cow);
    final bool isConfirmedPregnant = cow.status == 'PREGNANT' ||
        (cow.status == 'BRED_HEIFER' && (daysMated ?? 0) > 23) ||
        (cow.status == 'DRY' && cow.matingDate != null && (daysMated ?? 0) > 23);

    final bool isUnconfirmedMating = cow.matingDate != null && (daysMated ?? 0) <= 23;

    if (!isConfirmedPregnant && !isUnconfirmedMating) {
      showDialog(
        context: context,
        builder: (ctx) => _DeleteCowDialog(
          cowId: cowId,
          cowName: cowName,
        ),
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
            const Icon(Icons.pets_rounded, color: AppColors.deepGreen, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Manage Cow #$cowName',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textDark),
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
                  : 'Select an action for this mated cow (0–23 days):',
              style: const TextStyle(color: AppColors.textDark, fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            if (isConfirmedPregnant)
              InkWell(
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final success = await cowProvider.endPregnancy(cowId, widget.userId);
                  if (mounted) {
                    if (success) {
                      AppToast.showSuccess(context, '⚠️ Pregnancy ended for Cow #$cowName. Reverted to Milking status.');
                    } else {
                      AppToast.showError(context, cowProvider.errorMessage ?? 'Failed to end pregnancy.');
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
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'End Pregnancy (Mid-Term Loss)',
                              style: TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Logs mid-term loss / abortion and automatically reverts cow back to Milking status.',
                              style: TextStyle(color: AppColors.textDark, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              InkWell(
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final success = await cowProvider.reportHeatRepeated(cowId, widget.userId);
                  if (mounted) {
                    if (success) {
                      AppToast.showSuccess(context, '🔄 Heat repeated logged for Cow #$cowName. Reset status.');
                    } else {
                      AppToast.showError(context, cowProvider.errorMessage ?? 'Failed to update mating.');
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
                      const Icon(Icons.refresh_rounded, color: Color(0xFFE65100), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Heat Repeated / Cancel Mating',
                              style: TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Mating failed / heat repeated. Resets status so she can be mated again.',
                              style: TextStyle(color: AppColors.textDark, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            // Option 2: Remove / Delete Cow
            InkWell(
              onTap: () {
                Navigator.of(ctx).pop();
                showDialog(
                  context: context,
                  builder: (ctx2) => _DeleteCowDialog(
                    cowId: cowId,
                    cowName: cowName,
                  ),
                ).then((_) {
                  if (!mounted) return;
                  context.read<ActivityLogProvider>().loadActivities(widget.userId);
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.warningRed.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline_rounded, color: AppColors.warningRed, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Remove / Delete Cow',
                            style: TextStyle(color: AppColors.warningRed, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Remove cow from active herd due to sale, death, or cull.',
                            style: TextStyle(color: AppColors.textDark, fontSize: 12),
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

  // ── Add Dodi modal ────────────────────────────────────────────────────────

  void _onAddBuyerTap() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddDodiSheet(userId: widget.userId),
    );
    if (mounted) {
      Provider.of<ActivityLogProvider>(context, listen: false).loadActivities(widget.userId);
    }
  }

  // ── Add Cow modal ─────────────────────────────────────────────────────────

  void _onAddCowTap() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddCowSheet(userId: widget.userId),
    );
    if (mounted) {
      Provider.of<ActivityLogProvider>(context, listen: false).loadActivities(widget.userId);
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
    final farmName = authProvider.currentUser?.farmerName ??
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
          cows: cowProvider.cows.map((c) => ui_models.CowModel(
            id: c.id?.toString() ?? '',
            tagNumber: c.tagNumber,
            name: c.name ?? 'Cow #${c.tagNumber}',
            status: c.status.toUpperCase() == 'DRY'
                  ? ui_models.CowStatus.dry
                  : c.status.toUpperCase() == 'HEIFER'
                      ? ui_models.CowStatus.heifer
                      : (c.status.toUpperCase() == 'BRED_HEIFER' || c.status.toUpperCase() == 'BRED HEIFER')
                          ? ui_models.CowStatus.bredHeifer
                          : c.status.toUpperCase() == 'PREGNANT'
                              ? ui_models.CowStatus.pregnant
                              : ui_models.CowStatus.milking,
            hasLactated: cowProvider.hasLactated(c.id!),
            aiDate: c.matingDate,
            pregnancyMonth: cowProvider.getPregnancyMonth(c),
            daysSinceMating: cowProvider.getDaysSinceMating(c),
            peakMorningYield: c.peakMorningYield != null ? '${(c.peakMorningYield! / 1000).toStringAsFixed(1)} kg' : null,
            peakEveningYield: c.peakEveningYield != null ? '${(c.peakEveningYield! / 1000).toStringAsFixed(1)} kg' : null,
            lowestMorningYield: c.lowestMorningYield != null ? '${(c.lowestMorningYield! / 1000).toStringAsFixed(1)} kg' : null,
            lowestEveningYield: c.lowestEveningYield != null ? '${(c.lowestEveningYield! / 1000).toStringAsFixed(1)} kg' : null,
            estimatedBirthDate: c.estimatedBirthDate,
            displayAge: cowProvider.calculateAgeString(c),
          )).toList(),
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
          onViewAllTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ActivityLogScreen(),
            ),
          ),
          onNavTap: _onNavTap,
          onRefresh: () => DashboardRefreshCoordinator(context).refreshAll(widget.userId),
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
  final FlutterNativeContactPicker _contactPicker = FlutterNativeContactPicker();
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
            if (_nameController.text.trim().isEmpty && fullName != null && fullName.trim().isNotEmpty) {
              _nameController.text = fullName.trim();
            }
          });
        } else {
          if (!mounted) return;
          AppToast.showError(context, 'Selected contact does not have a phone number.');
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
      final err = Provider.of<DodiProvider>(context, listen: false).errorMessage;
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
                  icon: const Icon(Icons.contacts_rounded, color: AppColors.deepGreen, size: 22),
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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
  String _selectedStatus = 'MILKING';
  DateTime? _matingDate;
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if ((_selectedStatus == 'PREGNANT' || _selectedStatus == 'DRY') && _matingDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Mating Date is required for pregnant cows.'),
          backgroundColor: AppColors.warningRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
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
      final birthDate = DateTime(today.year - _ageYears, today.month - _ageMonths, today.day - _ageDays);
      estimatedBirthDateStr = "${birthDate.year.toString().padLeft(4, '0')}-${birthDate.month.toString().padLeft(2, '0')}-${birthDate.day.toString().padLeft(2, '0')}";
    }

    final success = await Provider.of<CowProvider>(context, listen: false).addCow(
      userId: widget.userId,
      tagNumber: _tagController.text.trim(),
      name: _nameController.text.trim().isEmpty ? null : _nameController.text.trim(),
      status: _selectedStatus,
      matingDate: _matingDate != null ? "${_matingDate!.year.toString().padLeft(4, '0')}-${_matingDate!.month.toString().padLeft(2, '0')}-${_matingDate!.day.toString().padLeft(2, '0')}" : null,
      hasLactatedBefore: (_selectedStatus == 'MILKING' || _selectedStatus == 'PREGNANT' || _selectedStatus == 'DRY') ? 1 : 0,
      estimatedBirthDate: estimatedBirthDateStr,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (success) {
      Navigator.of(context).pop();
      AppToast.showSuccess(context, 'Cow ${_tagController.text.trim()} added to herd.');
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
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Tag number is required' : null,
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
            const SizedBox(height: 14),

            // Status Selector (Adult Slider + Heifer/Bred Heifer Pills)
            _AddCowStatusSelector(
              selectedStatus: _selectedStatus,
              onStatusChanged: (val) {
                setState(() {
                  _selectedStatus = val;
                  if (val != 'PREGNANT' && val != 'DRY' && val != 'BRED_HEIFER') {
                    _matingDate = null;
                  }
                });
              },
            ),
            if (_selectedStatus == 'PREGNANT' || _selectedStatus == 'DRY' || _selectedStatus == 'BRED_HEIFER') ...[
              const SizedBox(height: 14),
              InkWell(
                onTap: () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: _matingDate ?? DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now(),
                  );
                  if (selected != null) {
                    setState(() => _matingDate = selected);
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: _selectedStatus == 'DRY' ? 'Dry-Off Date *' : 'Mating Date *',
                    prefixIcon: Icon(
                      _selectedStatus == 'DRY' ? Icons.bedtime_outlined : Icons.calendar_today_rounded,
                      size: 20,
                    ),
                  ),
                  child: Text(
                    _matingDate != null 
                        ? "${_matingDate!.year}-${_matingDate!.month.toString().padLeft(2, '0')}-${_matingDate!.day.toString().padLeft(2, '0')}"
                        : 'Select Date',
                    style: TextStyle(
                      color: _matingDate != null ? AppColors.textDark : AppColors.textGrey,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _selectedStatus == 'DRY' 
                    ? 'Date cow was dried off for pre-calving rest' 
                    : 'Auto-calculates expected calving date (+283 days)',
                style: const TextStyle(color: AppColors.textGrey, fontSize: 12),
              ),
              if (_matingDate != null && DateTime.now().difference(_matingDate!).inDays > 300) ...[
                const SizedBox(height: 8),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warningRed),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'This date is over 10 months ago — please confirm this is correct.',
                        style: TextStyle(color: AppColors.warningRed, fontSize: 12),
                      ),
                    ),
                  ],
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
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
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

  const _DeleteCowDialog({
    required this.cowId,
    required this.cowName,
  });

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
    if (_selectedReason == 'Other' && _otherReasonController.text.trim().isEmpty) {
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
    final bool canSubmit = _selectedReason != null &&
        (_selectedReason != 'Other' || _otherReasonController.text.trim().isNotEmpty);

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
              style: TextStyle(
                color: AppColors.textGrey,
                fontSize: 14,
              ),
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
                return DropdownMenuItem(
                  value: r,
                  child: Text(r),
                );
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
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
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
                          : const Text('Delete', style: TextStyle(fontWeight: FontWeight.w600)),
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
// Custom Status Selector for Add Cow Sheet
// ---------------------------------------------------------------------------
class _AddCowStatusSelector extends StatelessWidget {
  final String selectedStatus;
  final ValueChanged<String> onStatusChanged;

  const _AddCowStatusSelector({
    required this.selectedStatus,
    required this.onStatusChanged,
  });

  bool get isAdult => selectedStatus == 'MILKING' || selectedStatus == 'PREGNANT' || selectedStatus == 'DRY';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Status *',
              style: TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (isAdult)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.sageTint,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'ADULT COW',
                  style: TextStyle(
                    color: AppColors.deepGreen,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isAdult ? AppColors.cardSubtle : const Color(0xFFF0F0F4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isAdult ? AppColors.deepGreen.withValues(alpha: 0.4) : const Color(0xFFE5E5EA),
              width: isAdult ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              _AddSegmentTile(
                label: 'Milking',
                isSelected: selectedStatus == 'MILKING',
                onTap: () => onStatusChanged('MILKING'),
              ),
              _AddSegmentTile(
                label: 'Pregnant',
                isSelected: selectedStatus == 'PREGNANT',
                onTap: () => onStatusChanged('PREGNANT'),
              ),
              _AddSegmentTile(
                label: 'Dry',
                isSelected: selectedStatus == 'DRY',
                onTap: () => onStatusChanged('DRY'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _AddPillChip(
                label: 'Heifer',
                isSelected: selectedStatus == 'HEIFER',
                onTap: () => onStatusChanged('HEIFER'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AddPillChip(
                label: 'Bred Heifer',
                isSelected: selectedStatus == 'BRED_HEIFER',
                onTap: () => onStatusChanged('BRED_HEIFER'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AddSegmentTile extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _AddSegmentTile({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.deepGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
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
      ),
    );
  }
}

class _AddPillChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _AddPillChip({required this.label, required this.isSelected, required this.onTap});

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



