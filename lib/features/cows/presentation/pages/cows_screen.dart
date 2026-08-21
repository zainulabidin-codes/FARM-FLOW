import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/utils/app_toast.dart';
import '../../../../core/utils/pregnancy_display_utils.dart';
import '../models.dart';
import 'log_yields_screen.dart';
import 'package:provider/provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/cow_provider.dart' hide CowStatus;
import 'edit_cow_sheet.dart';

// ---------------------------------------------------------------------------
// CowsScreen
// ---------------------------------------------------------------------------
// Herd tracker — shows filter chips at the top and a scrollable list of
// cow cards below. Each card adapts its layout to the cow's status:
//   • Pregnant  → pregnancy month progress bar + warning / milestone label
//   • Milking   → health-score progress bar + optimal / at-risk label
//   • Dry       → simplified card with no progress bar
//
// Pure UI: all data arrives via parameters; all user actions are forwarded
// through callbacks.
// ---------------------------------------------------------------------------

class CowsScreen extends StatefulWidget {
  // ——————————————————————————————————————————————————————————————————————————

  /// Full herd list. The screen displays a filtered subset based on
  /// [widget.selectedFilter]; the parent is responsible for passing the correct
  /// filtered list or the full list (filtering can be done either side).
  final List<CowModel> cows;

  /// Currently active filter, e.g. "All", "Milking", "Pregnant", "Dry".
  /// Must match one of the values in [AppStrings.filterAll/Milking/…].
  final String selectedFilter;

  /// Index of the currently selected bottom-nav tab (3 = Herd).
  final int currentNavIndex;

  // ——————————————————————————————————————————————————————————————————————————

  /// Fired when the user taps a filter chip.
  /// [filter] is one of the AppStrings.filter* constants.
  final ValueChanged<String> onFilterChanged;

  /// Fired when the user taps the "+" icon to add a new cow.
  final VoidCallback onAddCowTap;

  /// Fired when the user taps a cow card.
  final ValueChanged<String> onCowCardTap;

  /// Fired when the user long-presses a cow card.
  final ValueChanged<String> onCowCardLongPress;

  /// Bottom-nav tap — propagated to the shell.
  final ValueChanged<int> onNavTap;

  const CowsScreen({
    super.key,
    required this.cows,
    required this.selectedFilter,
    required this.onFilterChanged,
    required this.onAddCowTap,
    required this.onCowCardTap,
    required this.onCowCardLongPress,
    required this.onNavTap,
    this.currentNavIndex = 3,
  });

  @override
  State<CowsScreen> createState() => _CowsScreenState();
}

class _CowsScreenState extends State<CowsScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<CowModel> _getVisibleCows(BuildContext context) {
    if (widget.cows.isEmpty) return [];
    
    var filtered = widget.cows;
    
    if (widget.selectedFilter != AppStrings.filterAll) {
      final milkingCowIds = context.read<CowProvider>().milkingCows.map((c) => c.id.toString()).toSet();
      final dryCowIds = context.read<CowProvider>().dryCows.map((c) => c.id.toString()).toSet();

      filtered = filtered.where((c) {
        if (widget.selectedFilter == 'Milking' && milkingCowIds.contains(c.id)) return true;
        if (widget.selectedFilter == 'Pregnant' && (c.status == CowStatus.pregnant || c.status == CowStatus.bredHeifer)) return true;
        if (widget.selectedFilter == 'Dry' && (c.status == CowStatus.dry || dryCowIds.contains(c.id))) return true;
        if (widget.selectedFilter == 'Heifer' && c.status == CowStatus.heifer) return true;
        if (widget.selectedFilter == 'Bred Heifer' && c.status == CowStatus.bredHeifer) return true;
        return false;
      }).toList();
    }
    
    if (_isSearching && _searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((c) => 
        c.name.toLowerCase().contains(q) || 
        c.tagNumber.toLowerCase().contains(q)
      ).toList();
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _getVisibleCows(context);

    return Scaffold(
      backgroundColor: AppColors.bgGrey,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ——————————————————————————————————————————————————————————————————
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: _isSearching
                  ? Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            decoration: const InputDecoration(
                              hintText: 'Search tag...',
                            ),
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        _IconCircleButton(
                          icon: Icons.close,
                          onTap: () {
                            setState(() {
                              _isSearching = false;
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
                        ),
                      ],
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          AppStrings.herd,
                          style: const TextStyle(
                            color: AppColors.textDark,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                        Row(
                          children: [
                            // Log Yields icon
                            _IconCircleButton(
                              icon: Icons.water_drop,
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const LogYieldsScreen()),
                                );
                              },
                            ),
                            const SizedBox(width: 10),
                            // Search icon
                            _IconCircleButton(
                              icon: Icons.search_rounded,
                              onTap: () {
                                setState(() {
                                  _isSearching = true;
                                });
                              },
                            ),
                            const SizedBox(width: 10),
                            // Add cow button
                            _IconCircleButton(
                              icon: Icons.add,
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                widget.onAddCowTap();
                              },
                              filled: true,
                            ),
                          ],
                        ),
                      ],
                    ),
            ),

            const SizedBox(height: 16),

            // ── Filter chips ──────────────────────────────────────────────
            _FilterChipRow(
              selected: widget.selectedFilter,
              onChanged: widget.onFilterChanged,
            ),

            const SizedBox(height: 16),

            // ── Cow list / empty state ────────────────────────────────────
            Expanded(
              child: visible.isEmpty
                  ? _EmptyState(
                      filter: widget.selectedFilter,
                      onAddTap: widget.onAddCowTap,
                    )
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final cow = visible[index];
                        return _CowCard(
                          cow: cow,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            widget.onCowCardTap(cow.id);
                          },
                          onLongPress: () {
                            HapticFeedback.heavyImpact();
                            widget.onCowCardLongPress(cow.id);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),

      // ── Bottom Navigation Bar ─────────────────────────────────────────────
      bottomNavigationBar: _CowsNavBar(
        currentIndex: widget.currentNavIndex,
        onTap: widget.onNavTap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _IconCircleButton — small grey or green circle icon button
// ---------------------------------------------------------------------------
class _IconCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool filled;

  const _IconCircleButton({
    required this.icon,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: filled ? AppColors.deepGreen : AppColors.cardWhite,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: filled ? 0.18 : 0.07),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: filled ? Colors.white : AppColors.textGrey,
          size: 20,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _FilterChipRow
// Horizontally scrolling row of filter chips: All | Milking | Pregnant | Dry
// The active chip is filled deepGreen; idle chips are white-outlined pills.
// ---------------------------------------------------------------------------
class _FilterChipRow extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _FilterChipRow({required this.selected, required this.onChanged});

  static const List<String> _filters = [
    AppStrings.filterAll,
    AppStrings.filterMilking,
    AppStrings.filterPregnant,
    AppStrings.filterDry,
    AppStrings.filterHeifer,
    AppStrings.filterBredHeifer,
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: _filters.map((filter) {
          final isSelected = filter == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _FilterChip(
              label: filter,
              isSelected: isSelected,
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(filter);
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.deepGreen : AppColors.cardWhite,
          borderRadius: BorderRadius.circular(22),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.deepGreen.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Text(
          label,
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

// ---------------------------------------------------------------------------
// _CowCard
// Adapts its internal layout based on [CowModel.status]:
//   CowStatus.pregnant → _PregnancyDetails
//   CowStatus.milking  → _MilkingDetails
//   CowStatus.dry      → _DryDetails
// ---------------------------------------------------------------------------
class _CowCard extends StatelessWidget {
  final CowModel cow;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _CowCard({
    required this.cow,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        constraints: const BoxConstraints(minHeight: 110),
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
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Row 1: Cow name + status badge ──────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cow.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '#${cow.tagNumber}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textGrey,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (cow.displayAge != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Age: ${cow.displayAge}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textGrey,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _StatusBadge(status: cow.status),
                IconButton(
                  icon: const Icon(Icons.edit, size: 20, color: AppColors.textGrey),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                  onPressed: () {
                    final cowProvider = context.read<CowProvider>();
                    final dbCow = cowProvider.cows.where((c) => c.id.toString() == cow.id).firstOrNull;
                    if (dbCow == null) return;
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => EditCowSheet(cow: dbCow),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ── Row 2: Status-specific details ───────────────────────────
            (() {
              switch (cow.status) {
                case CowStatus.pregnant: return _PregnancyDetails(cow: cow);
                case CowStatus.milking: return _MilkingDetails(cow: cow);
                case CowStatus.dry: return _DryDetails(cow: cow);
                case CowStatus.heifer: return _HeiferDetails(cow: cow);
                case CowStatus.bredHeifer: return _PregnancyDetails(cow: cow);
              }
            })(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _StatusBadge
// Coloured pill showing "Pregnant" (amber), "Milking" (green), "Dry" (grey).
// ---------------------------------------------------------------------------
class _StatusBadge extends StatelessWidget {
  final CowStatus status;
  const _StatusBadge({required this.status});

  Color get _bgColor => switch (status) {
        CowStatus.pregnant => AppColors.pregnantAmber,
        CowStatus.milking => AppColors.sageTint,
        CowStatus.dry => AppColors.dryGrey,
        CowStatus.heifer => AppColors.sageTint,
        CowStatus.bredHeifer => AppColors.pregnantAmber,
      };

  Color get _textColor => switch (status) {
        CowStatus.pregnant => AppColors.pregnantAmberText,
        CowStatus.milking => AppColors.deepGreen,
        CowStatus.dry => AppColors.dryGreyText,
        CowStatus.heifer => AppColors.deepGreen,
        CowStatus.bredHeifer => AppColors.pregnantAmberText,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: _textColor,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _PregnancyDetails
// Sub-card: bull + AI date info line, then a progress bar container showing
// "Month X of 9" on the left and a care-stage label on the right.
// ---------------------------------------------------------------------------
class _PregnancyDetails extends StatefulWidget {
  final CowModel cow;
  const _PregnancyDetails({required this.cow});

  @override
  State<_PregnancyDetails> createState() => _PregnancyDetailsState();
}

class _PregnancyDetailsState extends State<_PregnancyDetails> {
  bool _isRecordingCalving = false;
  bool _isMovingToDry = false;

  bool get _canMoveToDry {
    return widget.cow.needsSpecialCare && 
           widget.cow.status != CowStatus.dry;
  }

  Future<void> _handleMoveToDry() async {
    final provider = context.read<CowProvider>();
    final authProvider = context.read<AuthProvider>();

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Move to Dry Period'),
        content: Text('Move ${widget.cow.name} to Dry period now?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.deepGreen,
              foregroundColor: AppColors.cardWhite,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, Move to Dry'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    if (!mounted) return;
    
    setState(() => _isMovingToDry = true);
    
    final userId = authProvider.currentUser?.id;

    if (userId != null) {
      final success = await provider.updateCowStatus(
        cowId: int.parse(widget.cow.id),
        cowName: widget.cow.name,
        newStatus: 'DRY',
        userId: userId,
      );
      if (mounted) {
        if (success) {
          AppToast.showSuccess(context, '${widget.cow.name} moved to Dry period.');
        } else {
          AppToast.showError(context, 'Failed to move cow to Dry period.');
        }
      }
    }
    
    if (mounted) {
      setState(() => _isMovingToDry = false);
    }
  }

  Color get _careLabelColor {
    if (widget.cow.isInvalidPregnancy || widget.cow.isOverdue || widget.cow.needsSpecialCare) return AppColors.warningRed;
    return AppColors.deepGreen;
  }

  IconData get _careLabelIcon {
    if (widget.cow.isInvalidPregnancy) return Icons.error_outline_rounded;
    if (widget.cow.isOverdue) return Icons.alarm_rounded;
    if (widget.cow.needsSpecialCare) return Icons.warning_amber_rounded;
    return Icons.calendar_today_outlined;
  }

  Future<void> _handleRecordCalving() async {
    setState(() => _isRecordingCalving = true);
    final provider = context.read<CowProvider>();
    final authProvider = context.read<AuthProvider>();
    final userId = authProvider.currentUser?.id;

    if (userId != null) {
      final success = await provider.recordCalving(
        cowId: int.parse(widget.cow.id),
        cowName: widget.cow.name,
        userId: userId,
      );
      if (mounted) {
        if (success) {
          AppToast.showSuccess(context, 'Calving recorded for ${widget.cow.name}.');
        } else {
          AppToast.showError(context, 'Failed to record calving.');
        }
      }
    }
    if (mounted) {
      setState(() => _isRecordingCalving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = widget.cow.daysSinceMating ?? 0;
    final display = computePregnancyDisplay(
      daysSinceMating: days,
      pregnancyMonthOrdinal: widget.cow.pregnancyMonth,
    );
    final completedMonths = display.completedMonths;
    final remainingDays = display.remainingDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bull + AI date info row
        Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              size: 14,
              color: AppColors.textGrey,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                '${widget.cow.bullName != null ? "Bull: ${widget.cow.bullName}  |  " : ""}Mated: ${widget.cow.aiDate ?? "—"}',
                style: const TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Progress sub-card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.bgGrey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.cow.isInvalidPregnancy ? 'Data Error' : '$completedMonths months and $remainingDays days of 9 months',
                      style: TextStyle(
                        color: widget.cow.isInvalidPregnancy ? AppColors.warningRed : AppColors.textDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _careLabelIcon,
                        size: 14,
                        color: _careLabelColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.cow.pregnancyStageTag,
                        style: TextStyle(
                          color: _careLabelColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (!widget.cow.isInvalidPregnancy) ...[
                const SizedBox(height: 8),
                _ThinProgressBar(
                  fraction: widget.cow.pregnancyFraction,
                  color: AppColors.deepGreen,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2.0),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 13,
                      color: AppColors.textGrey,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      widget.cow.pregnancyStageMessage,
                      style: const TextStyle(
                        color: AppColors.textGrey,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.cow.isDueSoon || widget.cow.isOverdue || widget.cow.isInvalidPregnancy) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepGreen,
                      foregroundColor: AppColors.cardWhite,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: _isRecordingCalving 
                      ? const SizedBox.shrink()
                      : const Icon(Icons.child_care_rounded, size: 20),
                    label: _isRecordingCalving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cardWhite),
                        )
                      : const Text('Record Calving', style: TextStyle(fontWeight: FontWeight.w600)),
                    onPressed: _isRecordingCalving ? null : () => _handleRecordCalving(),
                  ),
                ),
              ],
              if (_canMoveToDry) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.deepGreen,
                      foregroundColor: AppColors.cardWhite,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: _isMovingToDry
                      ? const SizedBox.shrink()
                      : const Icon(Icons.bedtime_rounded, size: 20),
                    label: _isMovingToDry
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cardWhite),
                        )
                      : const Text('Move to Dry', style: TextStyle(fontWeight: FontWeight.w600)),
                    onPressed: _isMovingToDry ? null : () => _handleMoveToDry(),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (days < 211 && widget.cow.status == CowStatus.pregnant) ...[
          const SizedBox(height: 12),
          _MilkingDetails(cow: widget.cow),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------// ---------------------------------------------------------------------------
// _MilkingDetails
// Sub-card: yield + lactation info line.
// ---------------------------------------------------------------------------
class _MilkingDetails extends StatefulWidget {
  final CowModel cow;

  const _MilkingDetails({required this.cow});

  @override
  State<_MilkingDetails> createState() => _MilkingDetailsState();
}

class _MilkingDetailsState extends State<_MilkingDetails> {
  bool _isActionLoading = false;

  Future<void> _handleReportMating(BuildContext context) async {
    final DateTime initialDate = DateTime.now();
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.deepGreen,
              onPrimary: Colors.white,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null || !context.mounted) return;

    setState(() => _isActionLoading = true);

    try {
      final provider = context.read<CowProvider>();
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.currentUser?.id;

      if (userId == null) return;

      final formattedDate = "${pickedDate.year.toString().padLeft(4, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";

      final success = await provider.recordMating(
        cowId: int.parse(widget.cow.id),
        cowName: widget.cow.name,
        matingDate: formattedDate,
        userId: userId,
      );

      if (!context.mounted) return;

      if (success) {
        AppToast.showSuccess(context, 'Mating recorded successfully for ${widget.cow.name}.');
      } else {
        AppToast.showError(context, 'Failed to record mating.');
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleConfirmPregnancy() async {
    setState(() => _isActionLoading = true);
    try {
      final provider = context.read<CowProvider>();
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.currentUser?.id;
      if (userId == null) return;

      final success = await provider.confirmPregnancy(int.parse(widget.cow.id), userId);
      if (!mounted) return;
      if (success) {
        AppToast.showSuccess(context, '❤️ Pregnancy confirmed for ${widget.cow.name}!');
      } else {
        AppToast.showError(context, 'Failed to confirm pregnancy.');
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _handleHeatRepeated() async {
    setState(() => _isActionLoading = true);
    try {
      final provider = context.read<CowProvider>();
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.currentUser?.id;
      if (userId == null) return;

      final success = await provider.reportHeatRepeated(int.parse(widget.cow.id), userId);
      if (!mounted) return;
      if (success) {
        AppToast.showSuccess(context, '🔄 Heat repeated logged for ${widget.cow.name}. Mating reset.');
      } else {
        AppToast.showError(context, 'Failed to update mating state.');
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysMated = widget.cow.daysSinceMating;
    final bool hasActiveMating = widget.cow.aiDate != null && widget.cow.aiDate!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Peak (Morning)', style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    widget.cow.peakMorningYield ?? '—',
                    style: const TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Lowest (Morning)', style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    widget.cow.lowestMorningYield ?? '—',
                    style: const TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Peak (Evening)', style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    widget.cow.peakEveningYield ?? '—',
                    style: const TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Lowest (Evening)', style: TextStyle(color: AppColors.textGrey, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    widget.cow.lowestEveningYield ?? '—',
                    style: const TextStyle(color: AppColors.textDark, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Dynamic Mating / Record Action Bar
        if (hasActiveMating && daysMated != null && daysMated <= 23) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFB74D)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mated on ${widget.cow.aiDate} ($daysMated days ago)',
                  style: const TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.deepGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.favorite_rounded, size: 14),
                        label: const Text('Confirmed Pregnant', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: _isActionLoading ? null : () => _handleConfirmPregnancy(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.warningRed,
                          side: const BorderSide(color: AppColors.warningRed),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.refresh_rounded, size: 14),
                        label: const Text('Heat Repeated', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: _isActionLoading ? null : () => _handleHeatRepeated(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ] else if (!hasActiveMating) ...[
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.favorite_rounded, size: 16),
              label: const Text('Report Mating'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.sageTint,
                foregroundColor: AppColors.deepGreen,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _isActionLoading ? null : () => _handleReportMating(context),
            ),
          ),
          const SizedBox(height: 10),
        ],

        SizedBox(
          width: double.infinity,
          height: 36,
          child: OutlinedButton.icon(
            icon: const Icon(Icons.assessment_outlined, size: 16),
            label: const Text('View Milk Records'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.deepGreen,
              side: const BorderSide(color: AppColors.sageTint),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.of(context).pushNamed(
                '/per-cow-milk',
                arguments: widget.cow.id,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _DryDetails
// Minimal content for a dry cow — just a status line, no progress bar.
// ---------------------------------------------------------------------------
class _DryDetails extends StatelessWidget {
  final CowModel cow;
  const _DryDetails({required this.cow});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.bgGrey,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: const [
              Icon(
                Icons.bedtime_outlined,
                size: 16,
                color: AppColors.textGrey,
              ),
              SizedBox(width: 8),
              Text(
                'Resting period — no milk production',
                style: TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        if (cow.daysSinceMating != null) ...[
          const SizedBox(height: 12),
          _PregnancyDetails(cow: cow),
        ],
        if (cow.status != CowStatus.heifer && cow.status != CowStatus.bredHeifer) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.assessment_outlined, size: 16),
              label: const Text('View Milk Records'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.deepGreen,
                side: const BorderSide(color: AppColors.sageTint),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pushNamed(
                  '/per-cow-milk',
                  arguments: cow.id,
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// _ThinProgressBar
// Reusable animated progress track used for both pregnancy and health bars.
// ---------------------------------------------------------------------------
class _ThinProgressBar extends StatelessWidget {
  final double fraction;
  final Color color;

  const _ThinProgressBar({required this.fraction, required this.color});

  @override
  Widget build(BuildContext context) {
    final clamped = fraction.clamp(0.0, 1.0);
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          height: 6,
          width: constraints.maxWidth,
          decoration: BoxDecoration(
            color: const Color(0xFFDDDDDD),
            borderRadius: BorderRadius.circular(3),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOut,
              width: constraints.maxWidth * clamped,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// _EmptyState — shown when the filtered list returns no results.
// ---------------------------------------------------------------------------
class _EmptyState extends StatelessWidget {
  final String filter;
  final VoidCallback onAddTap;

  const _EmptyState({required this.filter, required this.onAddTap});

  @override
  Widget build(BuildContext context) {
    final isAll = filter == AppStrings.filterAll;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppColors.sageTint,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.pets_rounded,
                color: AppColors.deepGreen,
                size: 38,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isAll ? 'No Cows Added Yet' : 'No $filter Cows',
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isAll
                  ? 'Tap the + button to add your first cow to the herd.'
                  : 'No cows currently match the "$filter" filter.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textGrey,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (isAll) ...[
              const SizedBox(height: 28),
              SizedBox(
                width: 180,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: onAddTap,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Cow'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.deepGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CowsNavBar — 4-tab bottom nav, "Herd" active by default.
// ---------------------------------------------------------------------------
class _CowsNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _CowsNavBar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
                label: AppStrings.navHome,
                isActive: currentIndex == 0,
                onTap: () => onTap(0),
              ),
              _NavItem(
                icon: Icons.water_drop_outlined,
                activeIcon: Icons.water_drop_rounded,
                label: AppStrings.navMilk,
                isActive: currentIndex == 1,
                onTap: () => onTap(1),
              ),
              _NavItem(
                icon: Icons.account_balance_wallet_outlined,
                activeIcon: Icons.account_balance_wallet_rounded,
                label: AppStrings.navBuyers,
                isActive: currentIndex == 2,
                onTap: () => onTap(2),
              ),
              _NavItem(
                icon: Icons.pets_outlined,
                activeIcon: Icons.pets_rounded,
                label: AppStrings.navHerd,
                isActive: currentIndex == 3,
                onTap: () => onTap(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppColors.sageTint : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? AppColors.deepGreen : AppColors.textGrey,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppColors.deepGreen : AppColors.textGrey,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _HeiferDetails
// Minimal content for a heifer — not yet pregnant.
// ---------------------------------------------------------------------------
class _HeiferDetails extends StatefulWidget {
  final CowModel cow;
  const _HeiferDetails({required this.cow});

  @override
  State<_HeiferDetails> createState() => _HeiferDetailsState();
}

class _HeiferDetailsState extends State<_HeiferDetails> {
  bool _isRecordingMating = false;

  Future<void> _handleReportMating(BuildContext context) async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.deepGreen,
              onPrimary: Colors.white,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null || !context.mounted) return;

    setState(() => _isRecordingMating = true);

    try {
      final provider = context.read<CowProvider>();
      final authProvider = context.read<AuthProvider>();
      final userId = authProvider.currentUser?.id;

      if (userId == null) return;

      final formattedDate = "${pickedDate.year.toString().padLeft(4, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";
      
      final success = await provider.recordMating(
        cowId: int.parse(widget.cow.id),
        cowName: widget.cow.name,
        matingDate: formattedDate,
        userId: userId,
      );

      if (!context.mounted) return;

      if (success) {
        AppToast.showSuccess(context, 'Mating recorded successfully.');
      } else {
        AppToast.showError(context, 'Failed to record mating.');
      }
    } finally {
      if (mounted) setState(() => _isRecordingMating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.child_care_rounded,
                size: 16,
                color: AppColors.textGrey,
              ),
              SizedBox(width: 8),
              Text(
                'Young cow — not yet pregnant',
                style: TextStyle(
                  color: AppColors.textGrey,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.deepGreen,
                foregroundColor: AppColors.cardWhite,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: _isRecordingMating 
                ? const SizedBox.shrink()
                : const Icon(Icons.favorite_rounded, size: 20),
              label: _isRecordingMating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.cardWhite),
                  )
                : const Text('Report Mating', style: TextStyle(fontWeight: FontWeight.w600)),
              onPressed: _isRecordingMating ? null : () => _handleReportMating(context),
            ),
          ),
        ],
      ),
    );
  }
}




